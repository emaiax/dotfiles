{
  description = "emaiax nix-darwin and home configs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

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

      # environment.systemPackages = [
      #   pkgs.neovim
      #   pkgs.htop
      # ];

      # Enable alternative shell support in nix-darwin.
      # programs.fish.enable = true;
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
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.emaiax = {
              imports = [
                ./modules/home-manager.nix
              ];
            };
          }

          nix-homebrew.darwinModules.nix-homebrew {
            nix-homebrew.enable = true;
            nix-homebrew.user = "emaiax";

            nix-homebrew.autoMigrate = true; # automatically migrate packages from Homebrew to Nix
            # nix-homebrew.enableRosetta = true; # Apple Silicon only
          }
        ];
      };
    };

    # Expose the package set, including overlays
    darwinPackages = self.darwinConfigurations.dudumini.pkgs;
  };
}
