{ host, ... }:
{
  nix-homebrew = {
    enable = true;
    user = host.user.username;

    autoMigrate = true;
    enableRosetta = false;

    mutableTaps = true;
  };
}
