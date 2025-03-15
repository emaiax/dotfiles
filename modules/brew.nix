{ pkgs, ... }:
{
  homebrew = {
    enable = true;

    # onActivation.autoUpdate = true;
    # onActivation.upgrade    = true;
    onActivation.cleanup    = "zap";

    masApps = {
      "Tailscale" = 1475387142;
    };

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
  };
}