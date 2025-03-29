{ pkgs, ... }:
{
  # darwin-specific packages
  #
  environment.systemPackages = with pkgs; [
    arc-browser
    iterm2
    raycast
    nixfmt-rfc-style
  ];
}
