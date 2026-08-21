{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ./claude-automode.nix
    ./claude-code.nix
    ./claude-sandbox.nix
    ./claude-yolo.nix
    ./claudio.nix
    ./claudio-thebot.nix
    ./opencode.nix
  ];

  # Always on PATH, not devShell-gated like dudumox's build — this repo has no devShell.
  home.packages = [
    (pkgs.callPackage ./rtk.nix { rtkSrc = inputs.rtk-src; })
  ];
}
