{
  description = "emaiax nix-darwin and home configs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # rtk isn't in nixpkgs; build it from upstream source
    rtk-src = {
      url = "github:rtk-ai/rtk";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      home-manager,
      nix-darwin,
      nix-homebrew,
      nixpkgs,
      nix-vscode-extensions,
      ...
    }:
    let
      inventory = import ./nix/inventory.nix;

      homeManagerSetup =
        {
          lib,
          host,
          inputs,
          ...
        }:
        {
          home-manager = {
            backupFileExtension = "bak";

            useGlobalPkgs = true;
            useUserPackages = true;

            extraSpecialArgs = rec {
              inherit inputs;

              dotfilesPath = "${host.user.homeDirectory}/${host.user.repo}";
              claudioPath = "${dotfilesPath}/modules/user/apps/claudio";
            };

            users.${host.user.username} = {
              # Used for backwards compatibility, please read the changelog before changing.
              home.stateVersion = "25.05";

              home.username = lib.mkForce host.user.username;
              home.homeDirectory = lib.mkForce host.user.homeDirectory;

              # let home-manager manage itself
              programs.home-manager.enable = true;
            };
          };
        };

      mkDarwinHost =
        host:
        {
          extraModules ? [ ],
        }:
        nix-darwin.lib.darwinSystem {
          system = host.arch; # uses host's arch (aarch64/x86_64)

          specialArgs = { inherit inputs host; }; # pass the host variable to all the modules

          modules = [
            nix-homebrew.darwinModules.nix-homebrew # Homebrew integration
            home-manager.darwinModules.home-manager # HomeManager integration

            # core modules
            #
            ./modules/core

            # home manager configuration
            #
            homeManagerSetup

            # system configurations
            #
            ./modules/system/common # shared system settings
            ./modules/system/darwin # darwin-specific settings

            # custom configurations
            #
            ./nix/hosts/${host.hostname}.nix # host-specific overrides
            ./nix/profiles/${host.user.username}.nix # user-specific overrides
          ]
          ++ extraModules;
        };
    in
    {
      darwinConfigurations = builtins.mapAttrs (name: host: mkDarwinHost host { }) inventory.hosts;

      # CI builds the full darwin system closure on an ephemeral macOS runner,
      # which cannot build nix.linux-builder's aarch64-linux VM image itself
      # (no way to run Linux binaries on macOS, no remote builder registered)
      # and has no guarantee that cache.nixos.org already has that VM
      # substituted for whatever nixpkgs revision the flake currently pins.
      # This mirrors dudupro with linux-builder disabled so CI still catches
      # real eval/build regressions without depending on that cache.
      checks.aarch64-darwin.build-dudupro =
        (mkDarwinHost inventory.hosts.dudupro {
          extraModules = [ { nix.linux-builder.enable = nixpkgs.lib.mkForce false; } ];
        }).config.system.build.toplevel;

      formatter = nixpkgs.lib.genAttrs [
        "x86_64-darwin"
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ] (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
