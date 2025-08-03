# Example usage of mkVSCodeProfileModule
{
  config,
  lib,
  pkgs,
  ...
}:
let
  mkVSCodeProfileModule = import ./mkVSCodeProfileModule.nix;
in
{
  # Example 1: Basic VS Code configuration
  imports = [
    (mkVSCodeProfileModule {
      inherit config lib pkgs;
      name = "vscode";
      enable = true;
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
      extensions = with pkgs.vscode-marketplace; [
        teabyii.ayu
        eamodio.gitlens
        github.vscode-pull-request-github
      ];
      settings = {
        "editor.fontFamily" = "FiraCode Nerd Font, Monaco";
        "editor.fontSize" = 12;
        "workbench.colorTheme" = "Ayu Mirage Bordered";
      };
    })
  ];

  # Example 2: VS Code with profiles
  _module.args.vscodeWithProfiles = mkVSCodeProfileModule {
    inherit config lib pkgs;
    name = "vscode-with-profiles";
    enable = true;
    profiles = {
      default = {
        keybindings = [
          {
            key = "cmd+shift+c";
            command = "copyRelativeFilePath";
          }
        ];
        extensions = with pkgs.vscode-marketplace; [
          teabyii.ayu
          eamodio.gitlens
        ];
        settings = {
          "editor.fontSize" = 12;
        };
      };
      development = {
        extends = "default";
        extensions = with pkgs.vscode-marketplace; [
          brettm12345.nixfmt-vscode
          esbenp.prettier-vscode
          hashicorp.terraform
          jnoortheen.nix-ide
        ];
        settings = {
          "editor.formatOnSave" = true;
        };
      };
      minimal = {
        extensions = with pkgs.vscode-marketplace; [
          teabyii.ayu
        ];
        settings = {
          "editor.fontSize" = 14;
          "editor.minimap.enabled" = false;
        };
      };
    };
  };

  # Example 3: VS Code with custom package and directories
  _module.args.vscodeCustom = mkVSCodeProfileModule {
    inherit config lib pkgs;
    name = "vscode-custom";
    package = pkgs.vscode-fhs; # Use FHS version
    configDir = "${config.home.homeDirectory}/Library/Application Support/VSCode";
    userDataDir = "${config.home.homeDirectory}/.vscode-data";
    extensionsDir = "${config.home.homeDirectory}/.vscode-extensions";
    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    policies = {
      "update.mode" = "none";
      "extensions.autoUpdate" = false;
    };
    mimeTypes = {
      "text/plain" = "code.desktop";
      "application/json" = "code.desktop";
    };
    associations = {
      ".json" = "code.desktop";
      ".js" = "code.desktop";
    };
  };

  # Example 4: VS Code with external settings file
  _module.args.vscodeExternalSettings = mkVSCodeProfileModule {
    inherit config lib pkgs;
    name = "vscode-external-settings";
    enable = true;
    userSettings = "${config.xdg.configHome}/nix/modules/user/darwin/vscode/settings.json";
    keybindings = [
      {
        key = "cmd+shift+c";
        command = "copyRelativeFilePath";
      }
    ];
    extensions = with pkgs.vscode-marketplace; [
      teabyii.ayu
      eamodio.gitlens
    ];
  };

  # Example 5: VS Code with language-specific configuration
  _module.args.vscodeLanguageSpecific = mkVSCodeProfileModule {
    inherit config lib pkgs;
    name = "vscode-language-specific";
    enable = true;
    language = "nix";
    profiles = {
      nix = {
        extensions = with pkgs.vscode-marketplace; [
          brettm12345.nixfmt-vscode
          jnoortheen.nix-ide
        ];
        settings = {
          "[nix]" = {
            "editor.defaultFormatter" = "brettm12345.nixfmt-vscode";
          };
        };
      };
      rust = {
        extensions = with pkgs.vscode-marketplace; [
          rust-lang.rust-analyzer
          vadimcn.vscode-lldb
        ];
        settings = {
          "[rust]" = {
            "editor.defaultFormatter" = "rust-lang.rust-analyzer";
          };
        };
      };
    };
  };
}
