{ host, ... }:
{
  home-manager.users.${host.user.username} = {
    imports = [
      ../../modules/user
    ];
  };
}
