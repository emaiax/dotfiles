{ pkgs, ... }:
{
  nix.settings.trusted-users = [
    "root"
    "emaiax"
  ];

  nixpkgs.config = {
    allowUnfree = true;
  };

  users.users.emaiax = {
    name = "emaiax";
    home = "/Users/emaiax";
  };

  # security.pam.enableSudoTouchIdAuth = true;

  homebrew = {
    enable = true;
    brews = [
      "asdf"
      "curl"
      "direnv"
      "git"
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
    defaults = {
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
  };
}
