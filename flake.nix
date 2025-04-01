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
      # Define all users (supports multiple users)
      userVars = {
        emaiax = {
          username = "emaiax";
          homeDirectory = "/Users/emaiax";
        };
      };

      # Define all hosts (auto-scales when new hosts are added)
      hostVars = {
        dudumini = {
          hostname = "dudumini";
          arch = "x86_64-darwin";
          user = userVars.emaiax;
        };
        dudupro = {
          hostname = "dudupro";
          arch = "aarch64-darwin";
          user = userVars.emaiax;
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

            # ./hosts/common.nix # shared host config
            ./hosts/darwin # darwin-specific config

            ./modules/core/nix.nix # core nix settings
            ./modules/core/homebrew.nix # homebrew settings
            ./modules/core/home-manager.nix # home-manager settings and profiles modules

            ./modules/system/common # shared system settings
            ./modules/system/darwin # darwin-specific system settings

            ./hosts/${host.hostname}.nix # host-specific overrides
            # ./profiles/${host.user.username}.nix # user-specific overrides
          ];
        };
    in
    {
      darwinConfigurations = builtins.mapAttrs (name: host: mkDarwinHost host) hostVars;
    };
}
