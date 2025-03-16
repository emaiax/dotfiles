{ lib, pkgs, ... }:
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
          {
            key = "cmd+shift+c";
            command = "copyRelativeFilePath";
          }
          {
            key = "cmd+shift+s";
            command = "workbench.action.files.saveAll";
          }
        ];

        # https://code.visualstudio.com/docs/getstarted/settings#_settingsjson
        userSettings = {
          "editor.fontFamily" = "Monaco, Inconsolata Nerd Font, FiraCode Nerd Font, Hack Nerd Font";
          "editor.fontLigatures" = false;
          "editor.fontSize" = 12;
          "editor.fontVariations" = "'calt', 'ss02', 'ss08', 'zero', 'onum'";
          "editor.formatOnSave" = true;
          "editor.minimap.enabled" = false;
          "editor.tabSize" = 2;

          "explorer.confirmDelete" = false;
          "explorer.confirmDragAndDrop" = false;

          "telemetry.telemetryLevel" = "off";

          "workbench.colorTheme" = "Ayu Mirage Bordered";

          "[nix]" = {
            "editor.defaultFormatter" = "brettm12345.nixfmt-vscode";
          };
        };
      };
    };
  };

  home.activation = {
    vsCodeVimModeKeyRepeat = lib.hm.dag.entryAfter [ "installPackages" "vscodeProfiles" ] ''
      /usr/bin/defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
    '';
  };
}
