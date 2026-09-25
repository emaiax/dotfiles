{ inputs, pkgs, ... }:
{
  imports = [
    ./options.nix
    ./antigravity
    ./claude-code
    ./opencode
    ./profiles
  ];

  home.packages = [
    (pkgs.callPackage ./rtk/rtk.nix { rtkSrc = inputs.rtk-src; })
  ];
}
