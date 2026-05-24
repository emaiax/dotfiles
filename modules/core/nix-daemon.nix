{
  host,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  nix = {
    package = lib.mkDefault pkgs.nix;

    linux-builder = {
      enable = true;
      ephemeral = true;

      maxJobs = 4;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      supportedFeatures = [
        "kvm"
        "benchmark"
        "big-parallel"
      ];

      config = {
        virtualisation = {
          darwin-builder = {
            # diskSize = 10 * 1024; # defaults to 20G
            memorySize = 8 * 1024;
          };
        };
      };
    };

    settings = {
      experimental-features = "nix-command flakes";
      flake-registry = ./registry.json;
      accept-flake-config = true;

      trusted-users = [
        "root"
        host.user.username
      ];
    };

    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';
  };
}
