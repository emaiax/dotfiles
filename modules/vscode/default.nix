{
  config,
  lib,
  pkgs,
  ...
}:
let
  sourcePath = "${config.xdg.configHome}/nix/modules/vscode/settings.json";
  targetPath = "${config.home.homeDirectory}/Library/Application\ Support/Code/User/settings.json";
in
{
  # https://code.visualstudio.com/docs/getstarted/settings#_settingsjson
  #
  xdg.configFile."${targetPath}".source = config.lib.file.mkOutOfStoreSymlink sourcePath;

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
      };
    };
  };

  home.activation = {
    vsCodeVimModeKeyRepeat = lib.hm.dag.entryAfter [ "installPackages" "vscodeProfiles" ] ''
      /usr/bin/defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false

      /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    '';
  };
}
