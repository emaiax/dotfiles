{ pkgs, ... }:
{
  home.packages = [
    pkgs.just
    pkgs.just-lsp
  ];

  # global files are still buggy and doesn't work well,
  # waiting for: https://github.com/casey/just/pull/2692
  #
  # xdg.configFile."just/justfile".source = ../../../justfile; # root justfile
}
