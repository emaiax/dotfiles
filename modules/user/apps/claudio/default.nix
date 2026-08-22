{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ./claude-code
    ./opencode
    ./profiles/claudio-bot.nix
    ./profiles/claudio-yolo.nix
    ./profiles/claudio.nix
  ];

  # Not Claude-Code-specific: opencode uses it too (rtk-hook.sh is Claude-only today, but the binary itself isn't).
  home.packages = [
    (pkgs.callPackage ./rtk/rtk.nix { rtkSrc = inputs.rtk-src; })
  ];
}
