{ host, ... }:
{
  environment.variables = {
    HOMEBREW_NO_ANALYTICS = "1"; # disable analytics
    HOMEBREW_NO_ENV_HINTS = "1"; # disable env hints
    HOMEBREW_AUTO_UPDATE_SECS = "3600"; # update after 1 hour
  };

  nix-homebrew = {
    enable = true;
    user = host.user.username;

    autoMigrate = true;
    enableRosetta = false;

    mutableTaps = true;
  };
}
