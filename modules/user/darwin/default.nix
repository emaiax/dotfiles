{ config, ... }:
{
  imports = [
    ./fonts.nix
    ./packages.nix
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
