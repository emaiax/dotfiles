{ ... }:
{
  system = {
    defaults = {
      loginwindow = {
        # Disables the ability for a user to access the console by typing “>console” for a username at the login window
        DisableConsoleAccess = true;

        # Allow users to login to the machine as guests using the Guest account
        GuestEnabled = false;

        # Text to be shown on the login window
        LoginwindowText = "darwin+nix";
      };
    };
  };
}
