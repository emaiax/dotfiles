{ ... }:
{
  # https://macos-defaults.com
  # https://www.real-world-systems.com/docs/defaults.1.html
  # https://github.com/mathiasbynens/dotfiles/blob/master/.macos
  #
  imports = [
    ./dock.nix
    ./finder.nix
    ./login-window.nix
    ./keyboard.nix
  ];

  # update macOS settings after activation without needing to restart
  #
  system.activationScripts.postActivation.text = ''
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

    echo "Reloading macOS settings..."
  '';
}
