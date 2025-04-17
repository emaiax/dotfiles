{ ... }:
{
  # some of the resources may be outdated, but they are still useful:
  #
  # https://macos-defaults.com
  # https://ss64.com/mac/syntax-defaults.html
  # https://github.com/mathiasbynens/dotfiles/blob/master/.macos
  # https://developer.apple.com/documentation/devicemanagement/profile-specific-payload-keys
  #
  imports = [
    ./appearance.nix
    ./dock.nix
    ./finder.nix
    ./keyboard.nix
    ./login-window.nix
    ./system.nix
  ];

  # Close any open System Preferences panes, to prevent them from overriding settings we’re about to change
  #
  system.activationScripts.preActivation.text = ''
    echo "quitting System Preferences..."

    osascript -e 'tell application "System Preferences" to quit'
  '';

  # Disable Apple Intelligence and Siri
  #
  # defaults write com.apple.CloudSubscriptionFeatures.optIn "545129924" -bool "false"

  # TODO: this doesn't seem to work sometimes
  #
  # update macOS settings after activation without needing to restart
  #
  # system.activationScripts.postActivation.text = ''
  #   echo "reloading macOS settings..."

  #   /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  # '';
}
