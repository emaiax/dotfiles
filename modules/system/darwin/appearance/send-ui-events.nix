# https://github.com/NixOS/nixpkgs/blob/master/doc/stdenv/platform-notes.chapter.md
#
{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  name = "send-ui-events";
  version = "unstable";
  dontUnpack = true;

  src = ./send-ui-events;

  # ensure swift/apple-sdk is available and can run the script
  buildInputs = [ pkgs.apple-sdk ];

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/send-ui-events
  '';
}
