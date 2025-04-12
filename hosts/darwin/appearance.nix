{ ... }:
let
  accent = import ./appearance/accent-pink.nix;
in
{
  system = {
    defaults = {
      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";
      };
    };
  };

  system.activationScripts.postActivation.text = ''
    echo "setting up Appearance preferences..."

    #  Accent colors
    #
    #  this setting defines two properties:
    #    - AppleAccentColor
    #    - AppleAquaColorVariant
    #  it also presets AppleHighlightColor, but this can be overriden.
    #
    #  note that AppleAquaColorVariant is alway "1" except for "Graphite", where it is "6".
    #  note that the AccentColor "Blue" is default and has no AppleHighlightColor definition.
    #  note that when accent is changed back to "Blue", AppleHighlightColor and Accent color are also changed.
    #
    # | Color      | AppleAquaColorVariant | AccentColor | AppleHighlightColor                   |
    # | ---------- | :-------------------: | :---------: | ------------------------------------- |
    # | Multicolor |           1           |     nil     | nil                                   |
    # | Blue       |           1           |      4      | "0.698039 0.843137 1.000000 Blue"     |
    # | Purple     |           1           |      5      | "0.968627 0.831373 1.000000 Purple"   |
    # | Pink       |           1           |      6      | "1.000000 0.749020 0.823529 Pink"     |
    # | Red        |           1           |      0      | "1.000000 0.733333 0.721569 Red"      |
    # | Orange     |           1           |      1      | "1.000000 0.874510 0.701961 Orange"   |
    # | Yellow     |           1           |      2      | "1.000000 0.937255 0.690196 Yellow"   |
    # | Green      |           1           |      3      | "0.752941 0.964706 0.678431 Green"    |
    # | Graphite   |           6           |     -1      | "0.847059 0.847059 0.862745 Graphite" |
    #
    echo "setting UI accent color to ${accent.AccentColorName} (restart required to take effect)"
    defaults write NSGlobalDomain AppleAccentColor -int ${toString accent.AppleAccentColor}
    defaults write NSGlobalDomain AppleAquaColorVariant -int ${toString accent.AppleAquaColorVariant}
    defaults write NSGlobalDomain AppleHighlightColor -string "${accent.AppleHighlightColor}"
  '';
}
