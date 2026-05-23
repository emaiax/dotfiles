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

    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";

      # brew-src pinned to 5.1.7 breaks darwin-rebuild switch due to upstream regression in process_depends_on #138
      # see: https://github.com/zhaofengli/nix-homebrew/issues/138
      inputs.brew-src.url = "github:Homebrew/brew/master";
    };

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
      inventory = import ./nix/inventory.nix;

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

            # system configurations
            #
            ./modules/system/common # shared system settings
            ./modules/system/darwin # darwin-specific settings

            # host configurations
            #
            ./nix/hosts/${host.hostname}.nix # host-specific overrides

            # user settings and applications
            #
            ./modules/user/darwin/brew/${host.user.username}.brew.nix # user-specific brew settings
            ./nix/profiles/${host.user.username}.nix # user-specific overrides
          ];
        };
    in
    {
      darwinConfigurations = builtins.mapAttrs (name: host: mkDarwinHost host) inventory.hosts;
    };
}
