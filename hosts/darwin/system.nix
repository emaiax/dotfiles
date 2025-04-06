{ ... }:
{
  system = {
    defaults = {
      screensaver = {
        # If true, the user is prompted for a password when the screen saver is unlocked or stopped
        askForPassword = true;

        # The number of seconds to delay before the password will be required to unlock or stop the screen saver (the grace period).
        askForPasswordDelay = 120; # 2 minutes
      };

      NSGlobalDomain = {
        # Whether to use 24-hour or 12-hour time. The default is based on region settings.
        AppleICUForce24HourTime = true;

        # Whether to save new documents to iCloud by default
        NSDocumentSaveNewDocumentsToCloud = false;

        # Whether to use expanded save panel by default
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
      };
    };
  };
}
