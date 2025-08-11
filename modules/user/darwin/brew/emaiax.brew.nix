# this module is responsible for configuring homebrew and managing homebrew packages
# and should be imported by the darwin module and not by the home-manager module.
#
{ ... }:
{
  homebrew = {
    enable = true;

    # nix-homebrew is handling homebrew updates
    global.autoUpdate = true;

    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
    onActivation.cleanup = "zap";

    brews = [
      "mas"
      "openssl"
      "tfenv" # terraform version manager
      "tgenv" # terragrunt version manager
    ];

    casks = [
      # Productivity
      #
      "1password-cli" # 1password cli
      "1password" # 1password
      "arc" # arc browser
      # "claude" # claude ai
      # "cleanshot" # screenshots and screen recording
      "contexts" # context menu for mac
      "obsidian" # note taking
      "rectangle" # window manager
      "todoist-app" # task manager

      # Development
      #
      "cursor-cli" # cursor ai cli
      "docker-desktop" # docker desktop for mac
      # "tableplus" # database management
      "github" # github desktop for mac

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
      "logi-options+" # logitech options
      "the-unarchiver" # unarchiver
      "setapp" # setapp for mac
    ];

    masApps = {
      "Amphetamine" = 937984704;
      "Tailscale" = 1475387142;
    };
  };
}
