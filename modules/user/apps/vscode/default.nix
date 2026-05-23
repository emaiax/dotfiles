{
  config,
  lib,
  pkgs,
  ...
}:
let
  sourcePath = "${config.home.homeDirectory}/code/dotfiles/modules/user/apps/vscode/settings.json";

  targetDir = "${config.home.homeDirectory}/Library/Application Support/Code/User";
  targetPath = "${targetDir}/settings.json";
in
{
  # https://code.visualstudio.com/docs/configure/settings#_settings-json-file
  #
  xdg.configFile."${targetPath}".source = config.lib.file.mkOutOfStoreSymlink sourcePath;

  programs.vscode = {
    enable = true;

    profiles = {
      default = {
        extensions = with pkgs.vscode-marketplace; [
          # themes and icons
          #
          gulajavaministudio.mayukaithemevsc
          teabyii.ayu

          # ai
          anthropic.claude-code

          # languages and formatters
          #
          # golang.go
          hashicorp.hcl
          hashicorp.terraform
          # tamasfe.even-better-toml
          brettm12345.nixfmt-vscode
          # edwinkofler.vscode-assorted-languages
          esbenp.prettier-vscode
          # jakebecker.elixir-ls
          jnoortheen.nix-ide
          nefrob.vscode-just-syntax
          # phoenixframework.phoenix
          redhat.vscode-yaml
          # shopify.ruby-lsp

          # utilities
          #
          # mechatroner.rainbow-csv
          # naumovs.color-highlight
          eamodio.gitlens
          # github.vscode-pull-request-github # not supported yet
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

          # select all highlight matches in the editor
          #
          {
            key = "shift+cmd+d";
            command = "-workbench.view.debug";
            when = "viewContainer.workbench.view.debug.enabled";
          }
          {
            key = "shift+cmd+d";
            command = "-composer.fixerrormessage";
            when = "!chatModeMenuFocused && !composerFocused && @composer.isCursorOnLint";
          }
          {
            key = "shift+cmd+d";
            command = "-glass.toggleDesignMode";
            when = "glassEditorPanelVisible && isGlassAgentWorkspace && glassActiveTabKind == 'browser'";
          }
          {
            key = "shift+cmd+d";
            command = "editor.action.selectHighlights";
            when = "editorFocus";
          }
          {
            key = "shift+cmd+d";
            command = "selectAllSearchEditorMatches";
            when = "inSearchEditor";
          }
          {
            key = "shift+cmd+d";
            command = "notebook.selectAllFindMatches";
            when = "config.notebook.multiCursor.enabled && notebookFindWidgetFocused || config.notebook.multiCursor.enabled && notebookCellEditorFocused && activeEditor == 'workbench.editor.notebook'";
          }
        ];

        userMcp = {
          mcpServers = {
            atlassian = {
              url = "https://mcp.atlassian.com/v1/sse";
            };

            notion = {
              url = "https://mcp.notion.com/mcp";
              headers = { };
            };

            obsidian = {
              command = "uvx";
              args = [ "mcp-obsidian" ];
              env = {
                "OBSIDIAN_HOST" = "https://localhost";
                "OBSIDIAN_PORT" = "27124";
              };
            };

            tidewave = {
              command = "/usr/local/bin/mcp-proxy";
              args = [ "http://localhost:4000/tidewave/mcp" ];
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

  home.activation = {
    vsCodeVimModeKeyRepeat = lib.hm.dag.entryAfter [ "installPackages" "vscodeProfiles" ] ''
      /usr/bin/defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
    '';
  };
}
