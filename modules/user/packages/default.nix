{ pkgs, ... }:
{
  imports = [ ./fonts.nix ];

  home.packages = [
    pkgs.asdf-vm
    pkgs.btop
    pkgs.curl
    pkgs.jq
    pkgs.neovim
    pkgs.nixfmt
    pkgs.sops
    pkgs.tlrc
    pkgs.unixtools.watch # watch command for running a program periodically
    pkgs.watchexec # run a command when files change
    pkgs.wget
  ];
}
