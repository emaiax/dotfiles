{ config, inputs, ... }:
let
  ageKeyFile = "${config.xdg.configHome}/sops/age/keys.txt";
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  sops = {
    defaultSopsFile = ../../../secrets/secrets.enc.yaml;
    age.keyFile = ageKeyFile;
  };

  # so `sops <file>` works from an interactive shell without exporting this
  # by hand — sops's own default XDG lookup doesn't reliably resolve on
  # macOS outside a session that already has XDG_CONFIG_HOME set.
  home.sessionVariables.SOPS_AGE_KEY_FILE = ageKeyFile;

  # The homelab's domain suffix (e.g. "emx.casa"), not any one host on it — general-purpose, so
  # it lives here rather than under a single app module. Consumers so far: claude-code's sandbox
  # network allowlist (claude-hooks/homelab-network-hook.sh), wildcarding every homelab service
  # under it instead of patching one host at a time. Private, so it comes from a sops secret read
  # at shell startup instead of a nix-store literal — sops-nix decrypts asynchronously via a
  # launchd agent on macOS, so reading it at activation time would race that.
  sops.secrets.homelab-domain = { };

  programs.zsh.initContent = ''
    [[ -r "${config.sops.secrets.homelab-domain.path}" ]] &&
      export HOMELAB_DOMAIN="$(<"${config.sops.secrets.homelab-domain.path}")"
  '';
}
