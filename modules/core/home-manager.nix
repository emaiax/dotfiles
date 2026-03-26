# Home Manager configuration
{ lib, host, inputs, ... }:
{
  home-manager = {
    backupFileExtension = "bak";

    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };

    users.${host.user.username} = {
      # Used for backwards compatibility, please read the changelog before changing.
      home.stateVersion = "25.05";

      home.username = lib.mkForce host.user.username;
      home.homeDirectory = lib.mkForce host.user.homeDirectory;

      # let home-manager manage itself
      programs.home-manager.enable = true;
    };
  };
}
