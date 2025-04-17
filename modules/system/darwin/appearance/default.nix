{ config, lib, ... }:
let
  # https://mynixos.com/nix-darwin/option/system.defaults.NSGlobalDomain.AppleInterfaceStyle
  # Set to 'Dark' to enable dark mode, or leave unset for normal mode.
  #
  interfaceModes = {
    dark.appleInterfaceStyle = "Dark";
    light.appleInterfaceStyle = null;
  };

  accentColors = import ./accent-colors.nix;
  sendUIEvents = import ./send-ui-events.nix;

  # helpers to access the correct interface mode and color accent
  #
  currentMode = interfaceModes.${config.system.defaults.appearance.mode};
  currentAccent = accentColors.${config.system.defaults.appearance.accent};
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

    system.defaults = {
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
      setupInterfaceMode.text = ''
        echo "setting up appearance ${config.system.defaults.appearance.mode} mode..."

        osascript -e '
          tell application "System Events"
          to tell appearance preferences
          to set dark mode to ${
            if config.system.defaults.appearance.mode == "dark" then "true" else "false"
          }
        '
      '';

      setupAccentColor.text = ''
        echo "setting up appearance ${config.system.defaults.appearance.accent} accent..."

        ${sendUIEvents}/bin/send-ui-events
      '';

    };

    system.activationScripts.postUserActivation.text = ''
      ${config.system.activationScripts.setupInterfaceMode.text}
      ${config.system.activationScripts.setupAccentColor.text}
    '';
  };
}
