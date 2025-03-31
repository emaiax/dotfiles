{ ... }:
{
  imports = [
    ../../modules/common
    ../../modules/darwin
    ../../modules/darwin/brew.nix

    ./system.nix
  ];
}
