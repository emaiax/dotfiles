{ pkgs, ... }:
{
  programs.cursor = {
    enable = true;
    package = pkgs.code-cursor;

    profiles = {
      default = {
        extensions = with pkgs.vscode-marketplace; [
          eamodio.gitlens
          esbenp.prettier-vscode
        ];

        keybindings = [
          {
            key = "cmd+shift+c";
            command = "copyRelativeFilePath";
          }
          {
            key = "cmd+shift+s";
            command = "workbench.action.files.saveAll";
          }
          {
            "key" = "cmd+i";
            "command" = "composerMode.agent";
          }
          {
            key = "shift+cmd+b";
            command = "-workbench.view.backgroundAgent";
            when = "viewContainer.workbench.view.backgroundAgent.enabled";
          }
          {
            key = "shift+cmd+b";
            command = "-workbench.action.tasks.build";
            when = "taskCommandsRegistered";
          }
          {
            key = "shift+cmd+b";
            command = "workbench.action.toggleSidebarPosition";
          }
        ];

        mcp = {
          mcpServers = {
            tidewave = {
              command = "/path/to/mcp-proxy";
              args = [ "http://localhost:$PORT/tidewave/mcp" ];
            };

            obsidian = {
              command = "uvx";
              args = [ "mcp-obsidian" ];
              env = {
                "OBSIDIAN_HOST" = "<your_obsidian_host>";
                "OBSIDIAN_PORT" = "<your_obsidian_port>";
                "OBSIDIAN_API_KEY" = "<your_api_key>";
              };
            };
          };
        };

        settings = {
          "breadcrumbs.filePath" = "off";
          "cursor.composer.textSizeScale" = 1.15;
          "cursor.windowSwitcher.sidebarHoverCollapsed" = true;
          "editor.accessibilitySupport" = "off";
          "editor.colorDecorators" = true;
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
          "editor.fontFamily" = "FiraCode Nerd Font, Monaco, Inconsolata Nerd Font, Hack Nerd Font";
          "editor.fontLigatures" = true;
          "editor.fontSize" = 12;
          "editor.fontVariations" = "'calt', 'ss02', 'ss08', 'zero', 'onum'";
          "editor.formatOnSave" = true;
          "editor.inlineSuggest.enabled" = true;
          "editor.minimap.enabled" = false;
          "editor.renderWhitespace" = "all";
          "editor.suggestSelection" = "first";
          "editor.tabSize" = 2;
          "explorer.confirmDelete" = false;
          "explorer.confirmDragAndDrop" = false;
          "files.insertFinalNewline" = true;
          "files.trimFinalNewlines" = true;
          "files.trimTrailingWhitespace" = true;
          "git.ignoreMissingGitWarning" = true;
          "git.openRepositoryInParentFolders" = "never";
          "gitlens.telemetry.enabled" = false;
          "telemetry.telemetryLevel" = "off";
          "workbench.colorTheme" = "Ayu Mirage Bordered";
          "workbench.iconTheme" = "ayu";

          "[nix]" = {
            "editor.defaultFormatter" = "jnoortheen.nix-ide";
          };
        };
      };

      development = {
        extensions = with pkgs.vscode-marketplace; [
          jakebecker.elixir-ls
          shopify.ruby-lsp
        ];

        settings = {
          "files.autoSave" = "afterDelay";
          "files.autoSaveDelay" = 1000;
          "workbench.colorTheme" = "Default Dark+";
        };

        mcp = {
          mcpServers = {
            Github = {
              url = "https://api.githubcopilot.com/mcp/";
            };
            Cursor = {
              url = "https://api.cursor.com/mcp/";
            };
            Tidewave = {
              url = "https://api.tidewave.com/mcp/";
            };
            "Obsidian MCP" = {
              url = "https://obsidian.md/mcp/";
            };
          };
        };
      };

      work = {
        extensions = with pkgs.vscode-marketplace; [
          jnoortheen.nix-ide
          redhat.ansible
          redhat.vscode-yaml
        ];

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
