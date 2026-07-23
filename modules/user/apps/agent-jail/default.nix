{ lib, ... }:

let
  agentCatalog = import ./agents.nix;
in
{
  imports = [
    ./secrets.nix
    ./script.nix
    ./profiles.nix
  ];

  options.programs.agent-jail.profiles = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options.agents = lib.mkOption {
          type = lib.types.listOf (lib.types.enum (builtins.attrNames agentCatalog));
          description = "Assistant names this profile may be launched with.";
        };
      }
    );
    default = { };
    description = "Public, non-sensitive jail profile metadata. Actual paths live in the encrypted secret (see secrets.nix).";
  };
}
