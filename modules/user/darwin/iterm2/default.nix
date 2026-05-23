{ config, pkgs, ... }:
let
  sourcePath = "${config.xdg.configHome}/code/dotfiles/modules/user/darwin/iterm2/config";
  targetPath = "iterm2/com.googlecode.iterm2.plist";
in
{
  home.packages = [ pkgs.iterm2 ];

  xdg.configFile."${targetPath}" = {
    force = true;
    source = config.lib.file.mkOutOfStoreSymlink sourcePath;
  };
}
