{ config, lib, ... }:
let
  sourcePath = "${config.xdg.configHome}/nix/modules/iterm2/config";
  targetPath = "iterm2/com.googlecode.iterm2.plist";
in
{
  xdg.configFile."${targetPath}".source = config.lib.file.mkOutOfStoreSymlink sourcePath;
}
