# RTK isn't in nixpkgs, so build it straight from upstream source (`rtk-src` flake input)
#
{ rustPlatform, rtkSrc }:
rustPlatform.buildRustPackage {
  pname = "rtk";
  version = "0.42.4"; # bump with `nix flake update rtk-src`.
  src = rtkSrc;
  cargoLock.lockFile = "${rtkSrc}/Cargo.lock";
  # Upstream's test suite assumes a writable $HOME and `git` on PATH
  # (hook-install + tracking tests) — both unavailable in the Nix build
  # sandbox.
  doCheck = false;
}
