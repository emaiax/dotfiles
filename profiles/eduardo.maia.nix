{ host, ... }:
{
  home-manager.users.${host.user.username} = {
    imports = [
      ../modules/user/cli
      ../modules/user/darwin
      ../modules/user/git
      ../modules/user/shell
    ];

    programs.zsh = {
      initContent = ''
        # ulimit was low and sometimes hangs, setting to max value
        #
        ulimit -n 65536
      '';
    };
  };
}
