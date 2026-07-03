{ pkgs, ... }:
{
  imports = [
    ./git.nix
    ./gh.nix
  ];

  home.packages = [ pkgs.forgejo-cli ];
}
