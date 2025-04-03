{ ... }:
{
  # https://github.com/mathiasbynens/dotfiles/blob/master/.macos
  #
  system = {
    defaults = {
      dock = {
        autohide = true;
        orientation = "bottom";

        # Hot corner actions:
        #
        # 1: Disabled
        # 2: Mission Control
        # 3: Application Windows
        # 4: Desktop
        # 5: Start Screen Saver
        # 6: Disable Screen Saver
        # 7: Dashboard
        # 10: Put Display to Sleep
        # 11: Launchpad
        # 12: Notification Center
        # 13: Lock Screen
        # 14: Quick Note
        #
        wvous-bl-corner = 1; # Hot corner action for bottom left corner
        wvous-br-corner = 1; # Hot corner action for bottom right corner
        wvous-tl-corner = 1; # Hot corner action for top left corner
        wvous-tr-corner = 1; # Hot corner action for top right corner
      };
    };
  };
}
