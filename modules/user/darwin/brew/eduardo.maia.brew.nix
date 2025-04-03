# this module is responsible for configuring homebrew and managing homebrew packages
# and should be imported by the darwin module and not by the home-manager module.
# 
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
      "contexts"       # context menu for mac
      "github"         # github desktop for mac
      "logi-options+"  # logitech options
      "obsidian"       # note taking
      "rectangle"      # window manager
      "slack"          # communication
      "tableplus"      # database management
      "the-unarchiver" # unarchiver
    ];
  };
}
