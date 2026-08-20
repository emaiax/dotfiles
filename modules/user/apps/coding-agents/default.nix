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

  # Global, always-on token-reduction wrapper for coding-agent Bash calls (see claude-code.nix's PreToolUse hook). Unlike dudumox's devShell-gated build, this repo has no devShell — always on PATH is the equivalent here.
  home.packages = [
    (pkgs.callPackage ./rtk.nix { rtkSrc = inputs.rtk-src; })
  ];
}
