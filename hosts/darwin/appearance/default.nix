{
  config,
  lib,
  pkgs,
  ...
}:
let
  # https://github.com/NixOS/nixpkgs/blob/master/doc/stdenv/platform-notes.chapter.md
  sendUIEvents = pkgs.stdenv.mkDerivation {
    name = "send-ui-events";
    version = "unstable";
    dontUnpack = true;

    src = ./send-ui-events;

    # ensure swift/apple-sdk is available and can run the script
    buildInputs = [ pkgs.apple-sdk ];

    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/send-ui-events
    '';
  };

  colorAccents = import ./accent-colors.nix;

  # https://mynixos.com/nix-darwin/option/system.defaults.NSGlobalDomain.AppleInterfaceStyle
  # Set to 'Dark' to enable dark mode, or leave unset for normal mode.
  #
  interfaceModes = {
    dark.appleInterfaceStyle = "Dark";
    light.appleInterfaceStyle = null;
  };

  # helpers to access the correct interface mode and color accent
  currentMode = interfaceModes.${config.system.defaults.appearance.mode};
  currentAccent = colorAccents.${config.system.defaults.appearance.accent};
in
{
  options = {
    system.defaults.appearance = {
      accent = lib.mkOption {
        type = lib.types.enum (lib.attrNames colorAccents);
        default = "blue";
        example = "green";
        description = ''
          System appearance accent color. Available accents are: ${lib.concatStringsSep ", " (lib.attrNames colorAccents)}
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
        echo "setting up appearance mode to ${config.system.defaults.appearance.mode}..."

        osascript -e "
          tell application \"System Events\" \
          to tell appearance preferences \
          to set dark mode to ${
            if config.system.defaults.appearance.mode == "dark" then "true" else "false"
          }
        "
      '';

      setupAccentColor.text = ''
        echo "setting up appearance accent colors to ${config.system.defaults.appearance.accent}..."

        ${sendUIEvents}/bin/send-ui-events
      '';

    };

    system.activationScripts.postUserActivation.text = ''
      ${config.system.activationScripts.setupInterfaceMode.text}
      ${config.system.activationScripts.setupAccentColor.text}
    '';
  };
}
