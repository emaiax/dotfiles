{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;

    profiles = {
      default = {
        extensions = with pkgs.vscode-marketplace; [
          brettm12345.nixfmt-vscode
          esbenp.prettier-vscode
          jnoortheen.nix-ide
          teabyii.ayu	
          vscodevim.vim
        ];

        # https://code.visualstudio.com/docs/getstarted/keybindings#_advanced-customization
        keybindings = [
          { key = "cmd+shift+c"; command = "copyRelativeFilePath"; }
          { key = "cmd+shift+s"; command = "workbench.action.files.saveAll"; }
        ];

        # https://code.visualstudio.com/docs/getstarted/settings#_settingsjson
        userSettings = {
          # general settings
          #
          "breadcrumbs.filePath" = "off";
          "editor.formatOnSave" = true;
          "telemetry.telemetryLevel" = "off";
          "workbench.colorTheme" = "Ayu Mirage Bordered";

          # editor
          "editor.minimap.enabled" = false;
          "editor.tabSize" = 2;
          "explorer.confirmDelete" = false;
          "explorer.confirmDragAndDrop" = false;

          # "[nix]"."editor.defaultFormatter" = "nixfmt";
        };
      };
    };
  };
}
