{ config, ... }:
{
  imports = [
    ./cursor
    ./fonts.nix
    ./iterm2
    ./packages.nix
    ./raycast
    ./vscode
    # ./zed.nix
  ];

  # ensures ~/code folder exists.
  #
  home.activation.createCodeDir = ''
    mkdir -p ${config.home.homeDirectory}/code
  '';
}
