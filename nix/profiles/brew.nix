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
      "container" # apple containers
      "mas"
      "openssl"
    ];

    casks = [
      # Productivity
      #
      "1password-cli" # 1password cli
      "1password" # 1password
      "arc" # arc browser
      "claude" # claude for mac
      "contexts" # context menu for mac
      "obsidian" # note taking
      "rectangle" # window manager
      "todoist-app" # task manager
      "zen" # zen browser
      # "antinote" # installed via setapp
      # "cleanshot" # installed via setapp

      # Development
      #
      "github" # github desktop for mac
      # "docker-desktop" # docker desktop for mac
      # "tableplus" # installed via setapp

      # Media
      #
      "spotify" # music
      "vlc" # media player

      # Communication
      #
      "discord"
      "slack"
      "telegram"
      "whatsapp"

      # Utilities
      #
      "bambu-studio" # bambu studio for mac
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
