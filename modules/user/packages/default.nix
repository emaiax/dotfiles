{ pkgs, ... }:
{
  imports = [ ./fonts.nix ];

  home.packages = [
    pkgs.asdf-vm
    pkgs.btop
    pkgs.curl
    pkgs.jq
    pkgs.moreutils
    pkgs.neovim
    pkgs.nixfmt
    pkgs.sops
    pkgs.tlrc
    pkgs.unixtools.watch # watch command for running a program periodically
    pkgs.uv # ships uvx, needed on PATH for claude-mem's chroma-mcp vector search backend
    pkgs.watchexec # run a command when files change
    pkgs.wget

    # Was building but never installed anywhere; see #129.
    (pkgs.callPackage ../../pkgs { })
  ];
}
