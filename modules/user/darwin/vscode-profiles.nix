{ ... }:
{
  programs.vscode-profiles = {
    enable = true;

    profiles = {
      default = {
        extensions = [
          "esbenp.prettier-vscode"
          "dbaeumer.vscode-eslint"
        ];

        keybindings = [
          {
            key = "ctrl+p";
            command = "workbench.action.quickOpen";
          }
        ];

        settings = {
          "workbench.colorTheme" = "Default Light+";
          "workbench.editor.limit.enabled" = false;
          "workbench.editor.limit.max" = 100;
          "workbench.editor.limit.maxPerEditorGroup" = 100;
          "workbench.iconTheme" = "vscode-icons";
        };
      };
      development = {
        extensions = [
          "ms-vscode.cpptools"
          "ms-vscode.cmake-tools"
          "ms-vscode.makefile-tools"
        ];

        settings = {
          "files.autoSave" = "afterDelay";
          "files.autoSaveDelay" = 1000;
          "workbench.colorTheme" = "Default Dark+";
        };
      };
      work = {
        keybindings = [
          {
            key = "cmd+k ctrl+p";
            command = "workbench.action.quickOpen";
          }
        ];

        settings = {
          "workbench.colorTheme" = "Default Dark+";
        };
      };
    };
  };
}
