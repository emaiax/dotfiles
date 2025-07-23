{
  config,
  lib,
  pkgs,
  ...
}:
let
  sourcePath = "${config.xdg.configHome}/nix/modules/user/darwin/vscode/settings.json";

  targetDir = "${config.home.homeDirectory}/Library/Application Support/Code/User";
  targetPath = "${targetDir}/settings.json";
in
{
  # https://code.visualstudio.com/docs/getstarted/settings#_settingsjson
  #
  xdg.configFile."${targetPath}".source = config.lib.file.mkOutOfStoreSymlink sourcePath;

  programs.vscode = {
    enable = true;

    profiles = {
      default = {
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

        # search for vscode-extensions on https://search.nixos.org/packages
        extensions = with pkgs.vscode-marketplace; [
          # themes and icons
          #
          teabyii.ayu

          # git and github
          #
          eamodio.gitlens
          # github.copilot
          # github.copilot-chat
          # github.vscode-github-actions
          github.vscode-pull-request-github

          # languages and formatters
          #
          brettm12345.nixfmt-vscode
          esbenp.prettier-vscode
          # golang.go
          hashicorp.hcl # Packer HCL files
          hashicorp.terraform
          jakebecker.elixir-ls
          jnoortheen.nix-ide
          nefrob.vscode-just-syntax # justfile
          phoenixframework.phoenix
          redhat.ansible
          redhat.vscode-yaml
          samuelcolvin.jinjahtml
          shopify.ruby-lsp
          # tamasfe.even-better-toml
          # ziglang.vscode-zig

          # markdown previews
          #
          bierner.github-markdown-preview
          bierner.markdown-mermaid
          bierner.markdown-preview-github-styles

          # utilities
          #
          mechatroner.rainbow-csv
          naumovs.color-highlight
          vscodevim.vim
          wakatime.vscode-wakatime
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
