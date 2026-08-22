# rtk isn't in nixpkgs, so build it straight from upstream source (the
# `rtk-src` flake input). Mirrors dudumox's
# nix/modules/shared/packages/rtk.nix — version must be bumped by hand
# alongside `nix flake update rtk-src`.
{ rustPlatform, rtkSrc }:
rustPlatform.buildRustPackage {
  pname = "rtk";
  version = "0.42.4";
  src = rtkSrc;
  cargoLock.lockFile = "${rtkSrc}/Cargo.lock";
  # Upstream's test suite assumes a writable $HOME and `git` on PATH
  # (hook-install + tracking tests) — both unavailable in the Nix build
  # sandbox.
  doCheck = false;
}
