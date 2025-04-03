{ host, ... }:
{
  home-manager.users.${host.user.username} = {
    imports = [
      ../modules/user/cli
      ../modules/user/darwin
      ../modules/user/git
      ../modules/user/shell
    ];
  };
}
