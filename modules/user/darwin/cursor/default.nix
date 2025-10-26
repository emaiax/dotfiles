{ lib, pkgs, ... }:
{
  config = lib.mkIf true {
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
            "extensions.ignoreRecommendations" = true;
            "files.insertFinalNewline" = true;
            "files.trimFinalNewlines" = true;
            "files.trimTrailingWhitespace" = true;
            "git.ignoreMissingGitWarning" = true;
            "git.openRepositoryInParentFolders" = "never";
            "workbench.colorTheme" = "Mayukai Mirage Gruvbox Darktooth";
            "workbench.iconTheme" = "ayu";
          };

          extensions = with pkgs.vscode-marketplace; [
            # themes and icons
            #
            gulajavaministudio.mayukaithemevsc
            teabyii.ayu

            # languages and formatters
            #
            # golang.go
            # hashicorp.hcl
            # hashicorp.terraform
            # tamasfe.even-better-toml
            brettm12345.nixfmt-vscode
            edwinkofler.vscode-assorted-languages
            esbenp.prettier-vscode
            jakebecker.elixir-ls
            jnoortheen.nix-ide
            nefrob.vscode-just-syntax
            phoenixframework.phoenix
            redhat.vscode-yaml
            shopify.ruby-lsp

            # utilities
            #
            # mechatroner.rainbow-csv
            # naumovs.color-highlight
            github.vscode-pull-request-github
            vscodevim.vim
            wakatime.vscode-wakatime
          ];

          keybindings = [
            {
              command = "-workbench.view.backgroundAgent";
              key = "cmd+shift+b";
              when = "viewContainer.workbench.view.backgroundAgent.enabled";
            }
            {
              command = "-workbench.action.tasks.build";
              key = "cmd+shift+b";
              when = "taskCommandsRegistered";
            }
            {
              command = "workbench.action.toggleSidebarPosition";
              key = "cmd+shift+b";
            }

            # copy relative file path
            #
            {
              command = "copyRelativeFilePath";
              key = "cmd+shift+c";
            }

            # save all files
            #
            {
              command = "workbench.action.files.saveAll";
              key = "cmd+shift+s";
            }

            # FIXME: remove composer mode agent and access suggestions via cmd+i instead
            #
            {
              command = "composerMode.agent";
              key = "cmd+i";
            }

            # sort lines ascending and descending
            #
            {
              key = "shift+alt+a";
              command = "-editor.action.blockComment";
              when = "editorTextFocus && !editorReadonly";
            }
            {
              key = "shift+alt+a";
              command = "editor.action.sortLinesAscending";
            }
            {
              key = "shift+alt+z";
              command = "editor.action.sortLinesDescending";
            }

            # move editor group left and right (cycle editor groups)
            #
            {
              key = "cmd+r cmd+r";
              command = "workbench.action.moveActiveEditorGroupLeft";
              when = "activeEditorGroupLast";
            }
            {
              key = "cmd+r cmd+r";
              command = "workbench.action.moveActiveEditorGroupRight";
              when = "!activeEditorGroupLast";
            }
          ];

          mcp = {
            mcpServers = {
              tidewave = {
                command = "/usr/local/bin/mcp-proxy";
                args = [ "http://localhost:4000/tidewave/mcp" ];
              };

              obsidian = {
                command = "uvx";
                args = [ "mcp-obsidian" ];
                env = {
                  "OBSIDIAN_HOST" = "https://localhost";
                  "OBSIDIAN_PORT" = "27124";
                };
              };
            };
          };

          globalSnippets = {
            fixme = {
              prefix = [ "fixme" ];
              body = [ "$LINE_COMMENT $CURRENT_YEAR-$CURRENT_MONTH-$CURRENT_DATE FIXME: $0" ];
              description = "Insert a timestamped FIXME remark";
            };
            todo = {
              prefix = [ "todo" ];
              body = [ "$LINE_COMMENT $CURRENT_YEAR-$CURRENT_MONTH-$CURRENT_DATE TODO: $0" ];
              description = "Insert a timestamped TODO remark";
            };
          };

          languageSnippets = {
            elixir = {
              pry = {
                prefix = [ "pry" ];
                body = [ "require IEx; IEx.pry" ];
                description = "Insert a debug Pry statement";
              };

              pryfun = {
                prefix = [ "pryfun" ];
                body = [ "|> tap(fn input -> IO.inspect(input); require IEx; IEx.pry(); end)" ];
                description = "Pipe to a debug Pry statement";
              };
            };
          };
        };
      };
    };
  };
}
