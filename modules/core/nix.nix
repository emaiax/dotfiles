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
      enable = host.hostname == "dudupro";

      ephemeral = true;
      maxJobs = 4;
      systems = [ "x86_64-linux" ];

      mandatoryFeatures = [
        "kvm"
        "benchmark"
        "big-parallel"
      ];

      config = {
        nixpkgs.hostPlatform = "x86_64-linux";

        virtualisation = {
          darwin-builder = {
            # diskSize = 10 * 1024;
            memorySize = 8 * 1024;
          };
        };
      };
    };

    settings = {
      experimental-features = "nix-command flakes";
      flake-registry = ./registry.json;

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

  nixpkgs = {
    config = {
      allowBroken = false;
      allowUnfree = true;
      allowUnsupportedSystem = true;

      # some unmaintained packages are allowed to be installed
      #
      permittedInsecurePackages = map (pkg: pkg.name) [ pkgs.arc-browser ];
    };

    hostPlatform = host.arch;

    overlays = [ inputs.nix-vscode-extensions.overlays.default ];
  };

  system = {
    primaryUser = host.user.username;

    # Set Git commit hash for darwin-version.
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

    # Used for backwards compatibility, please read the changelog before changing.
    stateVersion = 6;
  };
}
