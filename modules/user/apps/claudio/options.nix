{ lib, ... }:
{
  options.programs.claudio = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable claudio pair programming assistant suite.";
    };

    backend = lib.mkOption {
      type = lib.types.enum [
        "claude-code"
        "agy"
        "opencode"
      ];
      default = "claude-code";
      description = "Default execution runtime for the claudio CLI profiles.";
    };

    permissions = {
      commands = {
        extraAllow = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "cargo *"
            "pnpm *"
            "just build *"
            "watchexec *"
          ];
          description = "Commands automatically approved across all backends (agy, claude-code, opencode).";
        };

        extraAsk = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "darwin-rebuild switch *"
            "just switch *"
            "brew install *"
            "kubectl apply *"
          ];
          description = "Commands requiring interactive human confirmation before execution.";
        };

        extraDenyHard = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "sudo nix-collect-garbage *"
            "sops decrypt *"
            "op item delete *"
            "terraform destroy *"
          ];
          description = "Irreversible commands strictly blocked across all profiles.";
        };
      };

      network = {
        extraAllowedDomains = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "api.linear.app" ];
          description = "Additional network domains allowed through Seatbelt sandbox egress.";
        };
      };

      filesystem = {
        extraCredentials = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "\${config.home.homeDirectory}/.kube/config" ];
          description = "Additional credential files/dirs strictly protected from reading and shell execution.";
        };

        extraToolchainPaths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "\${config.home.homeDirectory}/work" ];
          description = "Additional workspace directories granted read-write access in sandbox boundaries.";
        };
      };
    };

    rtk = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable RTK token reduction CLI wrappers and PreToolUse hooks.";
      };
    };
  };
}
