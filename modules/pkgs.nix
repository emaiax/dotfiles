{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    asdf
    curl
    direnv
    jq
    just
    neovim
    tlrc
    unixtools.watch
  ];
}
