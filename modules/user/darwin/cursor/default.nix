{ pkgs, ... }:
{
  programs.cursor = {
    enable = true;

    profiles = {
      default = {
        settings = {
          "[nix]" = {
            "editor.defaultFormatter" = "jnoortheen.nix-ide";
          };
          "breadcrumbs.filePath" = "off";
          "crashReporting.enabled" = "off";
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
          "workbench.colorTheme" = "Ayu Mirage Bordered";
          "workbench.iconTheme" = "ayu";
        };

        extensions = with pkgs.vscode-marketplace; [
          # themes and icons
          #
          gulajavaministudio.mayukaithemevsc
          teabyii.ayu

          # languages and formatters
          #
          edwinkofler.vscode-assorted-languages
          esbenp.prettier-vscode
          golang.go
          hashicorp.hcl # Packer HCL files
          hashicorp.terraform
          jakebecker.elixir-ls
          jnoortheen.nix-ide
          nefrob.vscode-just-syntax
          phoenixframework.phoenix
          redhat.vscode-yaml
          shopify.ruby-lsp

          # utilities
          #
          mechatroner.rainbow-csv
          naumovs.color-highlight
          vscodevim.vim
          wakatime.vscode-wakatime
        ];

        keybindings = [
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
            key = "cmd+shift+b";
            command = "workbench.action.toggleSidebarPosition";
          }
          {
            key = "cmd+shift+c";
            command = "copyRelativeFilePath";
          }
          {
            key = "cmd+shift+s";
            command = "workbench.action.files.saveAll";
          }
          {
            key = "cmd+i";
            command = "composerMode.agent";
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

      };
    };
  };
}
