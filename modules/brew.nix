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
    ];

    casks = [
      "1password-cli"
      "1password"
      "cleanshot"
      "contexts"
      "discord"
      "ghostty"
      "github" # github desktop for mac
      "logi-options+" # logitech options
      "iterm2"
      "obsidian"
      "rectangle"
      "setapp"
      "slack"
      "spotify"
      "tableplus"
      "telegram"
      "the-unarchiver"
      "vlc"
      "whatsapp"
    ];

    masApps = {
      "Amphetamine" = 937984704;
      "Tailscale" = 1475387142;
    };
  };
}
