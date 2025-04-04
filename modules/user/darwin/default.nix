{ config, ... }:
{
  imports = [
    ./arc-browser
    ./fonts.nix
    ./iterm2
    ./raycast
    ./vscode
  ];

  # ensures ~/code folder exists.
  #
  home.activation.createCodeDir = ''
    mkdir -p ${config.home.homeDirectory}/code
  '';
}
