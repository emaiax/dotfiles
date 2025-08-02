{ config, pkgs, ... }:
let
  sourceDir = "${config.xdg.configHome}/nix/modules/user/darwin/cursor";

  appSupportDir = "${config.home.homeDirectory}/Library/Application Support/Cursor/User";
  userConfigDir = "${config.home.homeDirectory}/.cursor";
in
{
  # install code-cursor via home-manager
  home.packages = [ pkgs.code-cursor ];

  # link cursor settings using mkOutOfStoreSymlink so the settings are actually stored outside of
  # the nix store, making it writable by the user
  #
  home.file = {
    "${appSupportDir}/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${sourceDir}/settings.json";

    "${appSupportDir}/keybindings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${sourceDir}/keybindings.json";

    "${userConfigDir}/extensions/extensions.json".source =
      config.lib.file.mkOutOfStoreSymlink "${sourceDir}/extensions.json";
  };
}
