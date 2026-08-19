{ lib, ... }:
let
  # Shared with claude-code.nix.
  gates = import ./gates.nix;

  # last-matching-rule-wins, evaluated in *declaration* order — Nix attrsets don't preserve that order when serialized to JSON (keys come out alphabetical), so every rule after the "*" catch-all has to be pinned with entryAfter or it can silently reorder ahead of it.
  prefixRule = action: cmd: {
    name = gates.opencodePatterns.${cmd} or "${cmd}*";
    value = lib.hm.dag.entryAfter [ "*" ] action;
  };
  exactRule = action: cmd: {
    name = cmd;
    value = lib.hm.dag.entryAfter [ "*" ] action;
  };
  gateRules = builtins.listToAttrs (
    map (prefixRule "ask") gates.ask
    # Both tiers: OpenCode has no classifier for the soft tier to live in.
    ++ map (prefixRule "deny") (gates.denyHard ++ gates.denySoft)
    ++ map (exactRule "ask") gates.askExact
  );
in
{
  programs.opencode = {
    enable = true;

    # Personal agent operating context as the global AGENTS.md; same source as programs.claude-code's ~/.claude/CLAUDE.md.
    context = ./AGENTS.md;

    skills = {
      # Shared vendored skills dir; same source as programs.claude-code.skills.
      nixpkgs-pr-checklist = ./skills/nixpkgs-pr-checklist;
    };

    settings = {
      model = "anthropic/claude-opus-5";
      # Cheap/routine tasks (title generation, etc.) skip the primary model.
      small_model = "anthropic/claude-haiku-4-5-20251001";

      # The package is managed by Nix, so this never auto-installs — it only checks and prints a notice, which is how we know to bump the flake input instead of drifting out of sync with it.
      autoupdate = "notify";

      # Disable remote sharing by default.
      share = "disabled";

      # Match the shell configured in this repo.
      shell = "zsh";

      # Per-turn undo of file edits (opencode default; explicit for clarity).
      snapshot = true;

      compaction.auto = true;

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
        // gateRules;
      };

      # Plugins loaded at startup. superpowers: brainstorming, planning, and execution workflow skills. supermemory: persistent cross-session memory (requires `bunx opencode-supermemory@latest login`).
      plugin = [
        "superpowers@git+https://github.com/obra/superpowers.git"
        "opencode-supermemory"
      ];
    };

    tui = {
      # Respect the system appearance setting on macOS.
      theme = "system";
    };
  };
}
