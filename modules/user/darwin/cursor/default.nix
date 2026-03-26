{ lib, inputs, ... }:
let
  hm = inputs.home-manager;

  # Same idea as `options.programs ? cursor`, but checking `options` here causes
  # infinite recursion when used in `imports`. The HM checkout path is stable.
  homeManagerHasProgramsCursor =
    builtins.pathExists "${hm}/modules/programs/cursor.nix"
    || builtins.pathExists "${hm}/modules/programs/cursor/default.nix";
in
{
  imports = lib.optional homeManagerHasProgramsCursor ./cursor.nix;
}
