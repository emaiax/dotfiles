{ ... }:
{
  system = {
    defaults = {
      # still depending on https://github.com/LnL7/nix-darwin/pull/699 to be merged
      # keyboard.shortcuts = {
      #   enable = true;
      #
      #   spotlight.search.enable = false;
      #   spotlight.search.finderSearch = false;
      # };

      NSGlobalDomain = {
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

        # Keyboard navigation with tab key
        # AppleKeyboardUIMode = "3";

        # Disable automatic capitalization
        NSAutomaticCapitalizationEnabled = false;
        # Disable smart dash substitution
        NSAutomaticDashSubstitutionEnabled = false;
        # Disable smart period substitution
        NSAutomaticPeriodSubstitutionEnabled = false;
        # Disable smart quotes substitution
        NSAutomaticQuoteSubstitutionEnabled = false;
        # Disable automatic spelling correction
        NSAutomaticSpellingCorrectionEnabled = false;
        # Disable automatic text replacement
        NSAutomaticInlinePredictionEnabled = false;
      };
    };
  };
}
