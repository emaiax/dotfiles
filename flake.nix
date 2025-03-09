{
  description = "emaiax nix-darwin and home configs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew }:
  let
    configuration = { pkgs, ... }: {

      environment.systemPackages =
        [
          pkgs.neovim
          pkgs.htop
        ];
      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Enable alternative shell support in nix-darwin.
      # programs.fish.enable = true;
      programs.zsh.enable = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 6;

      # The platform the configuration will be used on.
      # nixpkgs.hostPlatform = "aarch64-darwin"; # Apple Silicon
      nixpkgs.hostPlatform = "x86_64-darwin"; # Intel Mac
    };
  in
  {
    darwinConfigurations."dudumini" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        ];
    };

    # Expose the package set, including overlays
    darwinPackages = self.darwinConfigurations."dudumini".pkgs;
  };
}
