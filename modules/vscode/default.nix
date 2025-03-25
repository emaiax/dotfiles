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
          # themes and icons
          #
          teabyii.ayu
          emmanuelbeziat.vscode-great-icons

          bierner.github-markdown-preview
          bierner.markdown-preview-github-styles
          mechatroner.rainbow-csv
          ms-vscode.live-server
          naumovs.color-highlight
          vscodevim.vim
          wakatime.vscode-wakatime

          # git and github
          #
          eamodio.gitlens
          github.copilot
          github.copilot-chat
          github.vscode-github-actions
          github.vscode-pull-request-github

          # languages and formatters
          #
          brettm12345.nixfmt-vscode
          elixir-lsp.vscode-elixir-ls
          esbenp.prettier-vscode
          golang.go
          hashicorp.hcl # support for packer HCL files
          hashicorp.terraform
          jnoortheen.nix-ide
          redhat.ansible
          redhat.vscode-yaml
          samuelcolvin.jinjahtml
          shopify.ruby-lsp
          tamasfe.even-better-toml
          ziglang.vscode-zig
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
    '';
  };
}
