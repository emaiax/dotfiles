{ inputs, pkgs, ... }:
{
  imports = [
    ./claude-code
    ./opencode
    ./profiles/claudio-bot.nix
    ./profiles/claudio-yolo.nix
    ./profiles/claudio.nix
  ];

  home.packages = [
    (pkgs.callPackage ./rtk/rtk.nix { rtkSrc = inputs.rtk-src; })
  ];
}
