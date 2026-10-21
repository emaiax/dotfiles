{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  runner = lib.getExe pkgs.forgejo-runner;

  domainFile = config.sops.secrets.homelab-domain.path;
  secretFile = config.sops.secrets.dudupro-forgejo-runner-secret.path;

  logDir = "${config.home.homeDirectory}/Library/Logs";
  stateDir = "${config.xdg.stateHome}/forgejo-runner";

  # Host mode: jobs run straight on the Mac and reuse its nix store, the workspace under work/ is kept as a cache.
  runnerConfig = (pkgs.formats.yaml { }).generate "forgejo-runner.yml" {
    runner = {
      file = "${stateDir}/.runner";
      capacity = 1;
      labels = [ "macos:host" ];
    };
    host.workdir_parent = "${stateDir}/work";
  };

  # The registration secret is read at runtime from sops, so it never lands in the nix store.
  # The server side registers the same secret with `forgejo-cli actions register`, .runner is created once from it.
  start = pkgs.writeShellApplication {
    name = "forgejo-runner-start";
    text = ''
      mkdir -p "${stateDir}/work"
      cd "${stateDir}"
      if [[ ! -e .runner ]]; then
        ${runner} create-runner-file --config "${runnerConfig}" \
          --instance "https://forgejo.$(<"${domainFile}")" \
          --name ${osConfig.networking.hostName} \
          --secret "$(<"${secretFile}")"
      fi
      exec ${runner} daemon --config "${runnerConfig}"
    '';
  };
in
lib.mkIf (osConfig.networking.hostName == "dudupro") {
  sops.secrets.dudupro-forgejo-runner-secret = { };

  launchd.agents.forgejo-runner = {
    enable = true;
    config = {
      ProgramArguments = [ (lib.getExe start) ];
      # launchd agents get a minimal PATH. Jobs need nix, git, the CLT's swift, and node for JS actions like checkout.
      EnvironmentVariables.PATH = lib.concatStringsSep ":" [
        "${pkgs.nodejs_24}/bin"
        "/nix/var/nix/profiles/default/bin"
        "/run/current-system/sw/bin"
        "/usr/bin"
        "/bin"
        "/usr/sbin"
        "/sbin"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${logDir}/forgejo-runner.log";
      StandardErrorPath = "${logDir}/forgejo-runner.log";
    };
  };
}
