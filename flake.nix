{
  description = "emaiax nix-darwin and home configs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew }:
  let
    configuration = { pkgs, ... }: {
      nixpkgs.config.allowUnfree = true;

      environment.systemPackages =
        [
          pkgs.neovim
          pkgs.htop
        ];

      homebrew = {
        enable = true;
        brews = [
          "mas"
          "git"
          "direnv"
          "tlrc"
          "tmux"
          "curl"
          "asdf"
          "the_silver_searcher"
        ];
        casks = [
          "the-unarchiver"
        ];

        masApps = {
          "Tailscale" = 1475387142;
        };

        onActivation.autoUpdate = true;
        onActivation.upgrade    = true;
        onActivation.cleanup    = "zap";
      };

      system.defaults = {
        dock.autohide = true;

        finder.AppleShowAllExtensions = true;
        finder._FXShowPosixPathInTitle = true;

        NSGlobalDomain.AppleShowAllExtensions = true;
        NSGlobalDomain.InitialKeyRepeat = 14;
        NSGlobalDomain.KeyRepeat = 1;

        # trackpad.Clicking = true; # Whether to enable trackpad tap to click
        # trackpad.Dragging = true; # Whether to enable tap-to-drag

        # trackpad.TrackpadRightClick = true; # Whether to enable trackpad right click
        # trackpad.TrackpadThreeFingerDrag = true; # Whether to enable three finger drag
        # trackpad.TrackpadThreeFingerTapGesture = 0; # 0 to disable three finger tap, 2 to trigger Look up & data detectors
      };

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
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#simple
    darwinConfigurations."dudumini" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        nix-homebrew.darwinModules.nix-homebrew {
          nix-homebrew = {
            enable = true;
            user = "emaiax";

            autoMigrate = true; # automatically migrate packages from Homebrew to Nix
            # enableRosetta = true; # Apple Silicon only
          };
        }
        ];
    };

    # Expose the package set, including overlays
    darwinPackages = self.darwinConfigurations."dudumini".pkgs;
  };
}
