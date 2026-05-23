{
  config,
  lib,
  pkgs,
  ...
}:
let
  # https://mynixos.com/nix-darwin/option/system.defaults.NSGlobalDomain.AppleInterfaceStyle
  # Set to 'Dark' to enable dark mode, or leave unset for normal mode.
  #
  interfaceModes = {
    dark.appleInterfaceStyle = "Dark";
    light.appleInterfaceStyle = null;
  };

  accentColors = import ./appearance/accent-colors.nix;
  sendUIEvents = import ./appearance/send-ui-events.nix { inherit pkgs; };
in
{
  options = {
    system.defaults.appearance = {
      accent = lib.mkOption {
        type = lib.types.enum (lib.attrNames accentColors);
        default = "blue";
        example = "green";
        description = ''
          System appearance accent color. Available accents are: ${lib.concatStringsSep ", " (lib.attrNames accentColors)}
        '';
      };

      mode = lib.mkOption {
        type = lib.types.enum (lib.attrNames interfaceModes);
        example = "light";
        default = "dark";
        description = ''
          System appearance interface mode. Available modes are: ${lib.concatStringsSep ", " (lib.attrNames interfaceModes)}
        '';
      };
    };
  };

  config = {
    environment.systemPackages = [ sendUIEvents ];

    system.defaults =
      let
        currentMode = interfaceModes.${config.system.defaults.appearance.mode};
        currentAccent = accentColors.${config.system.defaults.appearance.accent};
      in
      {
        NSGlobalDomain = {
          # this requires the user to logout and login again.
          # toggling dark/ligh mode via osascript reflects immediatelly
          #
          AppleInterfaceStyle = lib.mkForce currentMode.appleInterfaceStyle;

          # never switch modes automatically
          AppleInterfaceStyleSwitchesAutomatically = lib.mkForce false;
        };

        CustomUserPreferences.NSGlobalDomain = {
          AppleAccentColor = lib.mkDefault (toString currentAccent.AppleAccentColor);
          AppleHighlightColor = lib.mkDefault (toString currentAccent.AppleHighlightColor);
          AppleAquaColorVariant = lib.mkDefault (toString currentAccent.AppleAquaColorVariant);
        };
      };

    system.activationScripts = {
      setupInterfaceMode.text =
        let
          isDarkMode = config.system.defaults.appearance.mode != "light";

          appleScriptDarkMode = if isDarkMode then "true" else "false";
          interfaceMode = if isDarkMode then "dark" else "light";
        in
        ''
          echo "setting up appearance mode to ${interfaceMode}..."

          osascript -e '
            tell application "System Events"
              tell appearance preferences
                set dark mode to ${appleScriptDarkMode}
              end tell
            end tell
          '
        '';

      setupAccentColor.text = ''
        echo "setting up appearance accent color to ${config.system.defaults.appearance.accent}..."

        # send UI events to update the accent color via Swift script
        ${sendUIEvents}/bin/send-ui-events
      '';
    };

    system.activationScripts.postActivation.text = ''
      ${config.system.activationScripts.setupInterfaceMode.text}
      ${config.system.activationScripts.setupAccentColor.text}
    '';
  };
}
