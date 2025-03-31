{ pkgs, ... }:
{
  # install darwin-specific packages via nixpkgs. if package can't be found in nixpkgs, use homebrew
  #
  home.packages = with pkgs; [
    arc-browser
    iterm2
    raycast
  ];
}
