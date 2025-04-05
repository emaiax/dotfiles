{ ... }:
{
  system = {
    defaults = {
      loginwindow = {
        # Disables the ability for a user to access the console by typing “>console” for a username at the login window
        DisableConsoleAccess = true;

        # Allow users to login to the machine as guests using the Guest account
        GuestEnabled = false;

        # Text in login window
        LoginwindowText = "";

        # Displays login window as a name and password field instead of a list of users
        SHOWFULLNAME = false;
      };
    };
  };

  system.activationScripts.preActivation.text = ''
    echo "setting up login window information"

    # Hide Other Accounts
    defaults write com.apple.loginwindow SHOWOTHERUSERS_MANAGED -bool false
  '';
}
