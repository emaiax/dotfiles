{ pkgs, ... }:
{
  # install darwin-specific packages via nixpkgs
  # if package can't be found in nixpkgs, use homebrew
  #

  # iterm2 is available in nixpkgs, but unsupported
  nixpkgs.config.allowUnsupportedSystem = true;

  home.packages = with pkgs; [
    arc-browser
    iterm2
    raycast
  ];
}
