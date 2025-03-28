{ pkgs, ... }:
{
  # https://github.com/NixOS/nixpkgs/blob/88a55dffa4d44d294c74c298daf75824dc0aafb5/pkgs/data/fonts/nerd-fonts/manifests/fonts.json
  fonts.packages = with pkgs.nerd-fonts; [
    fira-code
    hack
    inconsolata
    jetbrains-mono
    lilex
    meslo-lg
    monaspace
    zed-mono
  ];
}
