{
  description = "emaiax nix-darwin and home configs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # nixpkgs-unstable dropped x86_64-darwin support (26.11); dudumini (Intel)
    # pins to the last stable branch that still builds it, via nixpkgs.source.
    nixpkgs-darwin-stable.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

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
            extraSpecialArgs = { inherit inputs; };

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
          ];
        };
    in
    {
      darwinConfigurations = builtins.mapAttrs (name: host: mkDarwinHost host) inventory.hosts;

      formatter = nixpkgs.lib.genAttrs [
        "x86_64-darwin"
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ] (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
