{ ... }:
{
  homebrew = {
    enable = true;

    # nix-homebrew is handling homebrew updates
    global.autoUpdate = false;

    # onActivation.autoUpdate = true;
    # onActivation.upgrade    = true;
    onActivation.cleanup    = "zap";

    masApps = {
      "Tailscale" = 1475387142;
    };

    brews = [
      "mas"
      "the_silver_searcher"
      "watch"
    ];

    casks = [
      # "amphetamine"
      # "1password"
      # "discord"
      # "font-jetbrains-mono-nerd-font"
      # "font-jetbrains-mono"
      "github" # github desktop
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
  };
}
