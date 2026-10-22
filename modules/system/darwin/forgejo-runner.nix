{
  config,
  host,
  lib,
  pkgs,
  ...
}:
let
  user = host.user.username;
  hm = config.home-manager.users.${user};
  runner = lib.getExe pkgs.forgejo-runner;

  domainFile = hm.sops.secrets.homelab-domain.path;
  secretName = "${host.hostname}-forgejo-runner-secret";
  secretFile = hm.sops.secrets.${secretName}.path;

  logDir = "${host.user.homeDirectory}/Library/Logs";
  stateDir = "${hm.xdg.stateHome}/forgejo-runner";

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
        # Plain assignments, so errexit stops here if sops hasn't decrypted yet, instead of registering with empty values.
        domain=$(<"${domainFile}")
        secret=$(<"${secretFile}")
        ${runner} create-runner-file --config "${runnerConfig}" \
          --instance "https://forgejo.$domain" \
          --name ${host.hostname} \
          --secret "$secret"
      fi
      exec ${runner} daemon --config "${runnerConfig}"
    '';
  };
in
{
  home-manager.users.${user}.sops.secrets.${secretName} = { };

  # Local network privacy blocked the runner as an agent and as a daemon running as a user (TN3179, macOS 15.5+).
  # This exempts only Traefik's address, which fronts the forge. Takes effect after a reboot.
  system.defaults.CustomSystemPreferences."com.apple.network.local-network".AllowedWiFiLocalNetworkAddresses =
    [
      "192.168.68.21/32"
    ];

  # Only the first registration reads the sops secrets, which a user agent decrypts at login.
  # Before that the start script exits and KeepAlive retries, once .runner exists it starts at boot.
  launchd.daemons.forgejo-runner.command = lib.getExe start;
  launchd.daemons.forgejo-runner.serviceConfig = {
    UserName = user;
    # launchd gives a minimal PATH. Jobs need nix, git, the CLT's swift, and node for JS actions like checkout.
    EnvironmentVariables = {
      HOME = host.user.homeDirectory;
      PATH = lib.concatStringsSep ":" [
        "${pkgs.nodejs_24}/bin"
        "/nix/var/nix/profiles/default/bin"
        "/run/current-system/sw/bin"
        "/usr/bin"
        "/bin"
        "/usr/sbin"
        "/sbin"
      ];
    };
    RunAtLoad = true;
    KeepAlive = true;
    StandardOutPath = "${logDir}/forgejo-runner.log";
    StandardErrorPath = "${logDir}/forgejo-runner.log";
  };
}
