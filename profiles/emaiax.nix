{ ... }:
{
  # home-manager.users.${host.user.username} = {
  imports = [
    ../modules/user/apps
    ../modules/user/cli-tools
    ../modules/user/darwin
    ../modules/user/git
    ../modules/user/shell
  ];
  # };
}
