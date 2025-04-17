{ stdenv, ... }:
stdenv.mkDerivation {
  name = "custom-bins";
  version = "unstable";

  src = ./bin;

  installPhase = ''
    mkdir -p $out/bin
    cp $src/* $out/bin
  '';
}
