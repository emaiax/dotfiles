{
  config,
  lib,
  ...
}:
let
  home = config.home.homeDirectory;

  # Shared with claude-code.nix and sandbox.nix. Rendered into OpenCode's dag-entry shape by
  # permissions.nix's opencodeBashRules.
  perms = import ../permissions.nix { inherit home lib; };

  # Shared with claude-code.nix.
  settingsValues = import ../settings.nix;
in
{
  programs.opencode = {
    enable = true;

    # Personal agent operating context as the global AGENTS.md; same source as programs.claude-code's
    # ~/.claude/CLAUDE.md.
    context = ../AGENTS.md;

    skills = {
      # Shared vendored skills dir; same source as programs.claude-code.skills.
      nixpkgs-pr-checklist = ../skills/nixpkgs-pr-checklist;
    };

    settings = settingsValues.opencode // {
      permission = {
        read = {
          "*" = "allow";
          # Keep the default .env protection explicit — a bare "allow" string here isn't documented to preserve it.
          "*.env" = "deny";
          "*.env.*" = "deny";
          "*.env.example" = "allow";
        };
        glob = "allow";
        grep = "allow";
        lsp = "allow";
        edit = "allow";
        webfetch = "allow";
        websearch = "allow";
        task = "allow";
        # Touching paths outside the project — flag it.
        external_directory = "ask";
        # Same tool call repeated 3x with identical input — kill it, don't ask.
        doom_loop = "deny";

        bash = {
          "*" = "allow";
        }
        // perms.opencodeBashRules;
      };
    };

    tui = {
      # Respect the system appearance setting on macOS.
      theme = "system";
    };
  };
}
