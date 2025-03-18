{ config, ... }:
{
  xdg.configFile."iterm2/com.googlecode.iterm2.plist" = {
    source = config.lib.file.mkOutOfStoreSymlink ./config;
  };
}
