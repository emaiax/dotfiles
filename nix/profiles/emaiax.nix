{ host, ... }:
{
  imports = [ ./brew.nix ];

  home-manager.users.${host.user.username} = {
    imports = [
      ../../modules/user
    ];
  };
}
