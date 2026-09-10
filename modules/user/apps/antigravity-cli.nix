# Google's Antigravity agent CLI (binary name: agy). No home-manager module exists upstream for it,
# unlike Claude Code/opencode; this just puts the binary on PATH, run `agy` or `agy install` by hand.
{ pkgs, ... }:
{
  home.packages = [ pkgs.antigravity-cli ];
}
