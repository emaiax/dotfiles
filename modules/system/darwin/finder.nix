{ ... }:
{
  system = {
    defaults = {
      finder = {
        # keep folders on top when sorting by name on the desktop
        _FXSortFoldersFirstOnDesktop = true;

        # show the full POSIX filepath in the window title
        _FXShowPosixPathInTitle = false;

        # Show all file extensions in Finder
        AppleShowAllExtensions = true;

        # Show hidden files in Finder
        AppleShowAllFiles = false;

        # Change the default search scope, use "SCcf" to default to current folder
        # The default is unset ("This Mac")
        #
        FXDefaultSearchScope = "SCcf";

        # show warnings when change the file extension of files
        FXEnableExtensionChangeWarning = false;

        # Change the default finder view.
        #
        # "icnv" = Icon view
        # "Nlsv" = List view
        # "clmv" = Column View
        # "Flwv" = Gallery View The default is icnv.
        #
        FXPreferredViewStyle = "Nlsv";

        # remove items in the trash after 30 days
        FXRemoveOldTrashItems = true;

        # Change the default folder shown in Finder windows, "Other" corresponds to the value of NewWindowTargetPath
        # The default is unset ("Recents")
        #
        # null or one of "Computer", "OS volume", "Home", "Desktop", "Documents", "Recents", "iCloud Drive", "Other"
        #
        NewWindowTarget = "Home";
        #
        # Sets the URI to open when NewWindowTarget is "Other".
        # Spaces and similar characters must be escaped.
        # If the value is invalid, Finder will open your home directory.
        # Example: "file:///Users/foo/long%20cat%20pics".
        #
        # NewWindowTargetPath = "~/";

        # Allow quitting of the Finder. The default is false.
        QuitMenuItem = false;

        # Show path breadcrumbs in finder windows. The default is false.
        ShowPathbar = true;

        # Show status bar at bottom of finder windows with item/disk space stats. The default is false.
        ShowStatusBar = true;

        # Show external disks on desktop. The default is true.
        ShowExternalHardDrivesOnDesktop = true;

        # Show connected servers on desktop. The default is false.
        ShowMountedServersOnDesktop = true;

        # Show removable media (CDs, DVDs and iPods) on desktop. The default is true.
        ShowRemovableMediaOnDesktop = true;
      };

      NSGlobalDomain = {
        AppleShowAllExtensions = true;
      };
    };
  };

  system.activationScripts.postActivation.text = ''
    echo "setting up Finder preferences..."

    # Avoid creating .DS_Store files on network or USB volumes
    #
    # defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
    # defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

    # Expand the following File Info panes: “General” and “Open with”
    #
    defaults write com.apple.finder FXInfoPanesExpanded -dict General -bool true OpenWith -bool true MetaData -bool true
  '';
}
