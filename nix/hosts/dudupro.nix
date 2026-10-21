{ ... }:
{
  imports = [
    ../../modules/system/darwin/forgejo-runner.nix
    ../../modules/system/darwin/networking.nix
    ../../modules/system/darwin/security/pam-touch-id.nix
    ../../modules/system/darwin/trackpad.nix
  ];
}
