{
  description = "emaiax nix-darwin and home configs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # still depending on https://github.com/LnL7/nix-darwin/pull/699 to be merged
    # nix-darwin.url = "github:lnl7/nix-darwin/pull/699/head";
    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{
      self,
      home-manager,
      nix-darwin,
      nix-homebrew,
      nixpkgs,
  }:
  let
    configuration = { pkgs, ... }: {
      # Used for backwards compatibility, please read the changelog before changing.
      system.stateVersion = 6;
      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;
      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Enable alternative shell support in nix-darwin.
      programs.zsh.enable = true;
    };
  in
  {
    darwinConfigurations =  {
      dudumini = nix-darwin.lib.darwinSystem {
        system = "x86_64-darwin"; # Intel
        modules = [
          configuration
          ./hosts/dudumini.nix

          home-manager.darwinModules.home-manager {
            home-manager.backupFileExtension = "bak";

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.users.emaiax = {
              imports = [
                ./modules/home-manager.nix
                ./modules/ssh.nix
                ./modules/bat.nix
                ./modules/git
              ];
            };
          }

          nix-homebrew.darwinModules.nix-homebrew {
            nix-homebrew = {
              enable = true;
              user = "emaiax";

              autoMigrate = true;
              enableRosetta = false; # use /opt/homebrew
            };
          }
        ];
      };

      dudupro = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin"; # Apple Silicon
        modules = [
          configuration
          ./hosts/dudupro.nix

          home-manager.darwinModules.home-manager {
            home-manager.backupFileExtension = "bak";

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.users.emaiax = {
              imports = [
                ./modules/home-manager.nix
                ./modules/ssh.nix
                ./modules/bat.nix
                ./modules/git
              ];
            };
          }

          nix-homebrew.darwinModules.nix-homebrew {
            nix-homebrew = {
              enable = true;
              user = "emaiax";

              autoMigrate = false;
              enableRosetta = false; # use /opt/homebrew
            };
          }
        ];
      };
    };

    # Expose the package set, including overlays
    darwinPackages = self.darwinConfigurations.dudumini.pkgs;
  };
}
