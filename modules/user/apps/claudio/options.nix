{ lib, ... }:
{
  options.programs.claudio = {
    backend = lib.mkOption {
      type = lib.types.enum [
        "claude-code"
        "agy"
        "opencode"
      ];
      default = "claude-code";
      description = "Default execution runtime for the claudio CLI profiles.";
    };
  };
}
