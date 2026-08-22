{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ./auto-mode.nix
    ./claude-code.nix
    ./sandbox.nix
  ];

  home.packages = [
    (pkgs.callPackage ./rtk.nix { rtkSrc = inputs.rtk-src; })
  ];
}
