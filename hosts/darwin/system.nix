{ ... }:
{
  system = {
    # still depending on https://github.com/LnL7/nix-darwin/pull/699 to be merged
    # keyboard.shortcuts = {
    #   enable = true;
    #
    #   spotlight.search.enable = false;
    #   spotlight.search.finderSearch = false;
    # };

    defaults = {
      dock = {
        autohide = true;
      };

      finder = {
        _FXShowPosixPathInTitle = false;
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "Nlsv";
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        ShowPathbar = false;
        ShowStatusBar = true;
      };

      NSGlobalDomain = {
        AppleShowAllExtensions = true;

        # Repeat a key when it is held down (false) or display the accented character selector (true)
        ApplePressAndHoldEnabled = false;

        # https://apple.stackexchange.com/questions/261163/default-value-for-nsglobaldomain-initialkeyrepeat
        # https://mac-key-repeat.zaymon.dev
        #
        # The step values that correspond to the sliders on the GUI are as follow (lower equals faster):
        #
        # KeyRepeat:        120, 90, 60, 30, 12, 6, 2
        # InitialKeyRepeat: 120, 94, 68, 35, 25, 15
        #
        InitialKeyRepeat = 15; # 225ms
        KeyRepeat = 4; # 60ms
      };
    };
  };

  # update macOS settings after activation without needing to restart
  #
  system.activationScripts.postActivation.text = ''
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    echo "Reloading macOS settings..."
  '';
}
