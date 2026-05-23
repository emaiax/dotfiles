# check https://github.com/NixOS/nixpkgs/blob/nixpkgs-unstable/pkgs/data/fonts/nerd-fonts/manifests/fonts.json for available fonts
#
{ pkgs, ... }:
{
  # enable fontconfig
  fonts.fontconfig.enable = true;

  # install fonts via home-manager: https://github.com/nix-community/home-manager/issues/605
  home.packages = with pkgs.nerd-fonts; [
    fira-code
  ];
}
