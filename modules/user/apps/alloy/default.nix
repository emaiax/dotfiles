{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  # Same name on the LAN and over the tailnet: the homelab DNS answers with Traefik's LAN or tailnet IP.
  domain = "emx.casa";
  hostname = osConfig.networking.hostName;

  logDir = "${config.home.homeDirectory}/Library/Logs";
  stateDir = "${config.xdg.dataHome}/alloy";

  # SopsNix/stdout is not shipped: sops-nix prints a generated age private key there.
  river = ''
    prometheus.exporter.unix "mac" {
      disable_collectors = ["thermal"]
    }

    prometheus.scrape "mac" {
      targets         = prometheus.exporter.unix.mac.targets
      forward_to      = [prometheus.remote_write.homelab.receiver]
      job_name        = "node-exporter"
      scrape_interval = "30s"
    }

    prometheus.remote_write "homelab" {
      endpoint {
        url = "https://prometheus.${domain}/api/v1/write"
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
        url = "https://loki.${domain}/loki/api/v1/push"
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
