{ config, inputs, ... }:
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  sops = {
    defaultSopsFile = ../../../secrets/secrets.enc.yaml;
    age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
  };
}
