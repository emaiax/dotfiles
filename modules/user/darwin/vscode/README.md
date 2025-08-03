# VS Code Profile Module

This module provides a flexible way to configure VS Code with support for multiple profiles, similar to the `mkFirefoxModule` pattern used in home-manager.

## Features

- **Profile Management**: Create multiple VS Code profiles with different configurations
- **Profile Inheritance**: Profiles can extend other profiles to inherit settings
- **Flexible Configuration**: Support for all VS Code options including settings, extensions, keybindings, and policies
- **External Settings**: Link to external settings files for better organization
- **macOS Integration**: Automatic macOS-specific configurations and activation scripts
- **Package Customization**: Use different VS Code packages (e.g., vscode-fhs)
- **Directory Customization**: Customize all VS Code directories

## Usage

### Basic Usage

```nix
{ config, lib, pkgs, ... }:
let
  mkVSCodeProfileModule = import ./mkVSCodeProfileModule.nix;
in
{
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
      ];
      extensions = with pkgs.vscode-marketplace; [
        teabyii.ayu
        eamodio.gitlens
      ];
      settings = {
        "editor.fontSize" = 12;
        "workbench.colorTheme" = "Ayu Mirage Bordered";
      };
    })
  ];
}
```

### Profile-based Configuration

```nix
{ config, lib, pkgs, ... }:
let
  mkVSCodeProfileModule = import ./mkVSCodeProfileModule.nix;
in
{
  imports = [
    (mkVSCodeProfileModule {
      inherit config lib pkgs;
      name = "vscode";
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
          extends = "default";  # Inherit from default profile
          extensions = with pkgs.vscode-marketplace; [
            brettm12345.nixfmt-vscode
            esbenp.prettier-vscode
            hashicorp.terraform
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
    })
  ];
}
```

### External Settings File

```nix
{ config, lib, pkgs, ... }:
let
  mkVSCodeProfileModule = import ./mkVSCodeProfileModule.nix;
in
{
  imports = [
    (mkVSCodeProfileModule {
      inherit config lib pkgs;
      name = "vscode";
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
    })
  ];
}
```

## Parameters

### Required Parameters

- `config`: The home-manager config
- `lib`: The nixpkgs lib
- `pkgs`: The nixpkgs packages
- `name`: Unique name for the VS Code instance (used for activation scripts)

### Optional Parameters

#### Basic Configuration
- `enable` (default: `true`): Enable VS Code
- `package` (default: `pkgs.vscode`): VS Code package to use
- `configDir` (default: `"${config.home.homeDirectory}/Library/Application Support/Code"`): VS Code configuration directory
- `userConfigDir` (default: `"${configDir}/User"`): User configuration directory

#### Update Settings
- `enableUpdateCheck` (default: `null`): Enable update checks
- `enableExtensionUpdateCheck` (default: `null`): Enable extension update checks

#### Directory Settings
- `userDataDir` (default: `null`): User data directory
- `extensionsDir` (default: `null`): Extensions directory
- `globalSnippetsDir` (default: `null`): Global snippets directory
- `userSnippetsDir` (default: `null`): User snippets directory
- `mutableExtensionsDir` (default: `null`): Mutable extensions directory

#### Configuration Files
- `keybindings` (default: `[]`): Keybindings configuration
- `settings` (default: `{}`): Settings configuration
- `userSettings` (default: `null`): Path to external user settings file
- `workspaceSettings` (default: `null`): Workspace settings
- `folderSettings` (default: `null`): Folder settings

#### Extensions and Language Support
- `extensions` (default: `[]`): List of extensions
- `language` (default: `null`): Language support configuration

#### Advanced Settings
- `extraArgs` (default: `[]`): Extra arguments for VS Code
- `extraWrapperArgs` (default: `[]`): Extra wrapper arguments
- `mimeTypes` (default: `{}`): MIME type associations
- `associations` (default: `{}`): File associations
- `policies` (default: `{}`): VS Code policies

#### Profile Configuration
- `profiles` (default: `{}`): Profile configurations

## Profile Configuration

Each profile can contain:

- `keybindings`: List of keybinding configurations
- `settings`: Settings configuration
- `extensions`: List of extensions
- `extends`: Name of profile to extend (inherit from)

### Profile Inheritance

Profiles can inherit from other profiles using the `extends` attribute:

```nix
profiles = {
  default = {
    settings = {
      "editor.fontSize" = 12;
    };
    extensions = [ /* base extensions */ ];
  };
  development = {
    extends = "default";  # Inherit from default profile
    settings = {
      "editor.formatOnSave" = true;  # Override/add settings
    };
    extensions = [ /* additional extensions */ ];
  };
};
```

## macOS Integration

The module automatically includes macOS-specific configurations:

- **Activation Scripts**: Disables key repeat for Vim mode
- **File Associations**: Sets up file associations for VS Code
- **Directory Structure**: Uses macOS-specific directory paths

## Examples

See `example-usage.nix` for comprehensive examples of different usage patterns.

## Migration from Existing Configuration

To migrate from an existing `programs.vscode` configuration:

1. Extract the configuration into the `mkVSCodeProfileModule` function
2. Move settings to the `settings` parameter or external file
3. Move keybindings to the `keybindings` parameter
4. Move extensions to the `extensions` parameter
5. Use `imports` to include the module

Example migration:

```nix
# Before
programs.vscode = {
  enable = true;
  extensions = [ /* extensions */ ];
  keybindings = [ /* keybindings */ ];
};

# After
imports = [
  (mkVSCodeProfileModule {
    inherit config lib pkgs;
    name = "vscode";
    enable = true;
    extensions = [ /* extensions */ ];
    keybindings = [ /* keybindings */ ];
  })
];
```