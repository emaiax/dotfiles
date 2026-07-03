{ ... }:
{
  homebrew = {
    enable = true;

    # nix-homebrew is handling homebrew updates
    global.autoUpdate = true;

    # https://github.com/zhaofengli/nix-homebrew/issues/131#issuecomment-4232502784
    onActivation.autoUpdate = false;

    onActivation.upgrade = true;
    onActivation.cleanup = "zap";

    brews = [
      "mas"
      "openssl"
    ];

    casks = [
      # Productivity
      #
      "1password-cli" # 1password cli
      "1password" # 1password
      # "antinote" # quick notes -> setapp
      "arc" # arc browser
      "claude" # claude for mac
      # "cleanshot" # screenshots and screen recording -> setapp
      "contexts" # context menu for mac
      "obsidian" # note taking
      "rectangle" # window manager
      "todoist-app" # task manager

      # Development
      #
      # "docker-desktop" # docker desktop for mac
      "github" # github desktop for mac
      # "tableplus" # database management -> setapp

      # Media
      #
      "spotify" # music
      "vlc" # media player

      # Communication
      #
      "discord"
      # "slack"
      "telegram"
      "whatsapp"

      # Utilities
      #
      "logi-options+" # logitech options
      "setapp" # setapp for mac
      "the-unarchiver" # unarchiver
    ];

    masApps = {
      "Amphetamine" = 937984704;
      "Tailscale" = 1475387142;
    };
  };
}
