{ config, ... }:
{
  imports = [
    ./arc-browser
    ./code-cursor.nix
    ./docker.nix
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
