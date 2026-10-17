{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  # Same name on the LAN and over the tailnet: the homelab DNS answers with Traefik's LAN or tailnet IP.
  # The domain is a sops secret, so Alloy reads it from the decrypted file at runtime, not at build time.
  domainFile = config.sops.secrets.homelab-domain.path;
  hostname = osConfig.networking.hostName;

  logDir = "${config.home.homeDirectory}/Library/Logs";
  stateDir = "${config.xdg.dataHome}/alloy";

  # SopsNix/stdout is not shipped: sops-nix prints a generated age private key there.
  # max_backoff_retries keeps logs queued in memory while offline, the default drops them after about 6 minutes.
  river = ''
    local.file "domain" {
      filename = "${domainFile}"
    }

    prometheus.exporter.unix "mac" {
      disable_collectors = ["thermal"]
    }

    discovery.relabel "mac" {
      targets = prometheus.exporter.unix.mac.targets

      rule {
        target_label = "job"
        replacement  = "node-exporter"
      }
    }

    prometheus.scrape "mac" {
      targets         = discovery.relabel.mac.output
      forward_to      = [prometheus.remote_write.homelab.receiver]
      scrape_interval = "30s"
    }

    prometheus.remote_write "homelab" {
      endpoint {
        url = "https://prometheus." + string.trim_space(local.file.domain.content) + "/api/v1/write"
      }

      external_labels = { hostname = "${hostname}" }
    }

    local.file_match "logs" {
      path_targets = [
        { __path__ = "${logDir}/SopsNix/stderr", job = "sops-nix" },
        { __path__ = "${logDir}/alloy.log", job = "alloy" },
      ]
    }

    loki.source.file "logs" {
      targets    = local.file_match.logs.targets
      forward_to = [loki.write.homelab.receiver]
    }

    loki.write "homelab" {
      endpoint {
        url = "https://loki." + string.trim_space(local.file.domain.content) + "/loki/api/v1/push"
        max_backoff_retries = 1000
      }

      external_labels = { hostname = "${hostname}" }
    }
  '';

  alloyConfig = pkgs.runCommandLocal "alloy-mac-config.alloy" { } ''
    cp ${pkgs.writeText "alloy-mac-config.alloy" river} "$out"
    ${lib.getExe pkgs.grafana-alloy} validate "$out"
  '';
in
{
  launchd.agents.alloy = {
    enable = true;
    config = {
      ProgramArguments = [
        (lib.getExe pkgs.grafana-alloy)
        "run"
        "--disable-reporting"
        "--storage.path=${stateDir}"
        "${alloyConfig}"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${logDir}/alloy.log";
      StandardErrorPath = "${logDir}/alloy.log";
    };
  };
}
