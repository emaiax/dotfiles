{
  description = "emaiax nix-darwin and home configs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      # url = "github:nix-community/home-manager";
      url = "/Users/emaiax/code/home-manager";
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
      vars = import ./vars.nix;

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
            ./modules/core/nix.nix # core nix settings
            ./modules/core/homebrew.nix # homebrew settings
            ./modules/core/home-manager.nix # home-manager settings and profiles modules

            # system configurations
            #
            ./modules/system/common # shared system settings
            ./modules/system/darwin # darwin-specific settings

            # host configurations
            #
            ./hosts/${host.hostname}.nix # host-specific overrides

            # user settings and applications
            #
            ./modules/user/darwin/brew/${host.user.username}.brew.nix # user-specific brew settings
            ./profiles/${host.user.username}.nix # user-specific overrides
          ];
        };
    in
    {
      darwinConfigurations = builtins.mapAttrs (name: host: mkDarwinHost host) vars.hosts;
    };
}
