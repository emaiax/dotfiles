{ ... }:
{
  system = {
    defaults = {
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
      };
    };
  };
}
