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

  # sops's XDG lookup doesn't reliably resolve on macOS without this.
  home.sessionVariables.SOPS_AGE_KEY_FILE = ageKeyFile;

  # Homelab domain suffix, general-purpose (not one app's secret) — exported to the shell in shell/zsh.nix.
  sops.secrets.homelab-domain = { };
}
