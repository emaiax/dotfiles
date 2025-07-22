{ ... }:
{
  imports = [
    ../modules/system/darwin/networking.nix
    ../modules/system/darwin/security/pam-watch-id.nix
  ];
}
