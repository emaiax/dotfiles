{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;

    userSettings = {
        # This property will be used to generate settings.json:
        # https://code.visualstudio.com/docs/getstarted/settings#_settingsjson
        "editor.formatOnSave" = true;
    };
  };
}
