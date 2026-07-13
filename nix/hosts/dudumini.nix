{ inputs, ... }:
{
  # nixpkgs-unstable dropped x86_64-darwin support (26.11); pin this host to
  # the last stable branch that still supports it (26.05, EOL end of 2026).
  nixpkgs.source = inputs.nixpkgs-darwin-stable;

  imports = [
    ../../modules/system/darwin/networking.nix
    ../../modules/system/darwin/security/pam-watch-id.nix
  ];
}
