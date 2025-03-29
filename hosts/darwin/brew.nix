{ ... }:
{
  environment.variables = {
    # disable analytics
    HOMEBREW_NO_ANALYTICS = "1";

    # update after 1 hour of the last update
    HOMEBREW_AUTO_UPDATE_SECS = "3600";
  };

  homebrew = {
    enable = true;

    # nix-homebrew is handling homebrew updates
    global.autoUpdate = true;

    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
    onActivation.cleanup = "zap";

    brews = [
      "mas"
    ];

    casks = [
      "1password-cli"  # 1password cli
      "1password"      # 1password
      "cleanshot"      # screenshots and screen recording
      "contexts"       # context menu for mac
      "github"         # github desktop for mac
      "logi-options+"  # logitech options
      "obsidian"       # note taking
      "rectangle"      # window manager
      "setapp"         # setapp
      "spotify"        # music
      "tableplus"      # database management
      "the-unarchiver" # unarchiver
      "vlc"            # media player
      
      # communication
      "discord"
      "slack"
      "telegram"
      "whatsapp"
    ];

    masApps = {
      "Amphetamine" = 937984704;
      "Tailscale" = 1475387142;
    };
  };
}
