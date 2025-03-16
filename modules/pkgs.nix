{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    pkgs.asdf
    pkgs.curl
    pkgs.direnv
    pkgs.just
    pkgs.neovim
    pkgs.tlrc
  ];
}
