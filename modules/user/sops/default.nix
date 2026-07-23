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
}
