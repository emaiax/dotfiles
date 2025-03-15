{ pkgs, ... }:
{
  nix.settings.trusted-users = [
    "root"
    "emaiax"
  ];

  environment.systemPackages = with pkgs; [ raycast ];

  nixpkgs.config = {
    allowUnfree = true;
  };

  users.users.emaiax = {
    name = "emaiax";
    home = "/Users/emaiax";
  };

  homebrew = {
    enable = true;

    brews = [
      "asdf"
      "curl"
      "direnv"
      "mas"
      "the_silver_searcher"
      "tlrc"
      "tmux"
      "watch"
    ];

    casks = [
      # "amphetamine"
      # "1password"
      # "discord"
      # "font-jetbrains-mono-nerd-font"
      # "font-jetbrains-mono"
      "the-unarchiver"
      # "arc"
      # "claude"
      # "cleanshot"
      # "contexts"
      # "discord"
      # "iterm2"
      # "podman"
      # "raycast"
      # "rio"
      # "setapp"
      # "slack"
      # "spotify"
      # "tableplus"
      # "telegram"
      # "visual-studio-code"
      # "vlc"
      # "whatsapp"
    ];

    masApps = {
      "Tailscale" = 1475387142;
    };

    # onActivation.autoUpdate = true;
    # onActivation.upgrade    = true;
    onActivation.cleanup    = "zap";
  };

  system = {
    # still depending on https://github.com/LnL7/nix-darwin/pull/699 to be merged
    # keyboard.shortcuts = {
    #   enable = true;
    #
    #   spotlight.search.enable = false;
    #   spotlight.search.finderSearch = false;
    # };

    defaults = {
      dock = {
        autohide = true;
      };

      finder = {
        _FXShowPosixPathInTitle = true;
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "Nlsv";
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        ShowPathbar = false;
        ShowStatusBar = true;
      };

      NSGlobalDomain.AppleShowAllExtensions = true;
      # NSGlobalDomain.InitialKeyRepeat = 14;
      # NSGlobalDomain.KeyRepeat = 14;
    };
  };
}
