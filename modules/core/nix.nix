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

    overlays = [
      inputs.nix-vscode-extensions.overlays.default
      # direnv + CGO_ENABLED=0 + Darwin Makefile -linkmode=external (nixpkgs#502769).
      # Remove after nixpkgs includes that postPatch (nix flake update).
      (_final: prev: {
        direnv = prev.direnv.overrideAttrs (old: {
          postPatch =
            (old.postPatch or "")
            + ''
              if grep -q -- ' -linkmode=external' GNUmakefile 2>/dev/null; then
                substituteInPlace GNUmakefile --replace-fail " -linkmode=external" ""
              fi
            '';
        });
      })
    ];
  };

  system = {
    primaryUser = host.user.username;

    # Set Git commit hash for darwin-version.
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

    # Used for backwards compatibility, please read the changelog before changing.
    stateVersion = 6;
  };
}
