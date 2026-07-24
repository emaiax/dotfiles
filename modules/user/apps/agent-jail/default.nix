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
        options.cwd = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.submodule {
              options.rw = lib.mkOption {
                type = lib.types.bool;
                description = "Whether the $(PWD) mount is read-write.";
              };
            }
          );
          default = null;
          description = "If set, also mounts the invocation-time $(PWD) into the jail at /jail/<basename>.";
        };
      }
    );
    default = { };
    description = "Public, non-sensitive jail profile metadata. Actual paths live in the encrypted secret (see secrets.nix).";
  };
}
