{
  description = "emaiax nix-darwin and home configs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # still depending on https://github.com/LnL7/nix-darwin/pull/699 to be merged
    # nix-darwin.url = "github:lnl7/nix-darwin/pull/699/head";
    nix-darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
  };

  outputs =
    inputs@{
      self,
      home-manager,
      nix-darwin,
      nix-homebrew,
      nixpkgs,
      nix-vscode-extensions,
    }:
    let
      ###################################
      # 1. Host variables
      ###################################
      hostVars = {
        dudumini = {
          hostname = "dudumini";
          arch = "x86_64-darwin";
        };

        dudupro = {
          hostname = "dudupro";
          arch = "aarch64-darwin";
        };
      };

      ###################################
      # 2. User variables
      ###################################
      userVars = {
        emaiax = {
          username = "emaiax";
          homeDirectory = "/Users/emaiax";
        };
      };

      # usernames = builtins.attrNames userVars;

      ###################################
      # 3. Base Darwin config function
      ###################################
      mkDarwinModule =
        host:
        { pkgs, ... }:
        {
          # Use nix from current nixpkgs
          #
          # nix.package = pkgs.nixVersions.stable; # Stable release
          # nix.package = pkgs.nixVersions.unstable; # Latest development version
          # nix.package = pkgs.nixFlakes; # Version with flake support enabled
          #
          nix.package = pkgs.nix;

          # TODO: remove nix.conf
          #
          # nix.extraOptions = ''
          #   experimental-features = nix-command flakes
          # '';

          # Necessary for using flakes on this system.
          nix.settings.experimental-features = "nix-command flakes";

          nix.settings.trusted-users = [ "root" ] ++ (builtins.attrNames userVars);

          # iterm2 is available in nixpkgs, but unsupported
          nixpkgs.config = {
            allowUnfree = true;
            allowUnsupportedSystem = true;
          };

          nixpkgs.hostPlatform = host.arch;

          nixpkgs.overlays = [ nix-vscode-extensions.overlays.default ];

          # Set Git commit hash for darwin-version.
          system.configurationRevision = self.rev or self.dirtyRev or null;

          # Used for backwards compatibility, please read the changelog before changing.
          system.stateVersion = 6;
        };

      ###################################
      # 4. Homebrew config function
      ###################################
      mkHomebrewModule = user: {
        nix-homebrew = {
          enable = true;
          user = user.username;

          autoMigrate = true;
          enableRosetta = false;
          mutableTaps = true;
        };
      };

      ###################################
      # 5. Home Manager config function
      ###################################
      mkHomeManagerModule = user: {
        home-manager = {
          backupFileExtension = "bak";

          useGlobalPkgs = true;
          useUserPackages = true;

          users.${user.username} =
            { lib, ... }:
            {
              home.stateVersion = "25.05";
              home.homeDirectory = lib.mkForce (user.homeDirectory);

              # let home-manager manage itself
              programs.home-manager.enable = true;

              # import home-manager modules
              imports = [ ./profiles/${user.username}.nix ];
            };
        };
      };
    in
    {
      darwinConfigurations = {
        dudupro = nix-darwin.lib.darwinSystem {
          modules = [
            nix-homebrew.darwinModules.nix-homebrew
            home-manager.darwinModules.home-manager

            (mkDarwinModule hostVars.dudupro)
            (mkHomebrewModule userVars.emaiax)
            (mkHomeManagerModule userVars.emaiax)

            # custom config per host
            ./hosts/dudupro.nix
          ];
        };

        dudumini = nix-darwin.lib.darwinSystem {
          modules = [
            nix-homebrew.darwinModules.nix-homebrew
            home-manager.darwinModules.home-manager

            (mkDarwinModule hostVars.dudumini)
            (mkHomebrewModule userVars.emaiax)
            (mkHomeManagerModule userVars.emaiax)

            # custom config per host
            ./hosts/dudumini.nix
          ];
        };
      };
    };
}
