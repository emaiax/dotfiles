{ lib, ... }:
{
  programs.opencode = {
    enable = true;

    # Personal agent operating context as the global AGENTS.md; same source as
    # programs.claude-code's ~/.claude/CLAUDE.md.
    context = ./AGENTS.md;

    skills = {
      # Shared vendored skills dir; same source as programs.claude-code.skills.
      nixpkgs-pr-checklist = ./skills/nixpkgs-pr-checklist;
    };

    settings = {
      model = "anthropic/claude-opus-5";
      # Cheap/routine tasks (title generation, etc.) skip the primary model.
      small_model = "anthropic/claude-haiku-4-5-20251001";

      # The package is managed by Nix, so this never auto-installs — it only
      # checks and prints a notice, which is how we know to bump the flake
      # input instead of drifting out of sync with it.
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
          # Keep the default .env protection explicit — a bare "allow"
          # string here isn't documented to preserve it.
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

        # last-matching-rule-wins, evaluated in *declaration* order — Nix
        # attrsets don't preserve that order when serialized to JSON (keys
        # come out alphabetical), so every rule after the "*" catch-all has
        # to be pinned with entryAfter or it can silently reorder ahead of it.
        bash = {
          "*" = "allow";

          "git commit*" = lib.hm.dag.entryAfter [ "*" ] "ask";
          "git push*" = lib.hm.dag.entryAfter [ "*" ] "deny";

          "gh pr create*" = lib.hm.dag.entryAfter [ "*" ] "deny";
          "gh pr ready*" = lib.hm.dag.entryAfter [ "*" ] "deny";
          "gh pr merge*" = lib.hm.dag.entryAfter [ "*" ] "deny";
          "gh pr review*" = lib.hm.dag.entryAfter [ "*" ] "deny";

          # This repo's Forgejo equivalent of the gh gates above.
          "fj pr create*" = lib.hm.dag.entryAfter [ "*" ] "deny";
          "fj pr merge*" = lib.hm.dag.entryAfter [ "*" ] "deny";
          "fj pr review*" = lib.hm.dag.entryAfter [ "*" ] "deny";
          "fj pr close*" = lib.hm.dag.entryAfter [ "*" ] "deny";
          "fj pr comment*" = lib.hm.dag.entryAfter [ "*" ] "deny";

          "git reset --hard*" = lib.hm.dag.entryAfter [ "*" ] "ask";
          "git checkout -- *" = lib.hm.dag.entryAfter [ "*" ] "ask";
          "git checkout ." = lib.hm.dag.entryAfter [ "*" ] "ask";
          "git restore*" = lib.hm.dag.entryAfter [ "*" ] "ask";
          "git clean*" = lib.hm.dag.entryAfter [ "*" ] "ask";
          "git rebase*" = lib.hm.dag.entryAfter [ "*" ] "ask";
          "rm -rf*" = lib.hm.dag.entryAfter [ "*" ] "ask";
        };
      };

      # Plugins loaded at startup.
      # superpowers: brainstorming, planning, and execution workflow skills.
      # supermemory: persistent cross-session memory (requires `bunx opencode-supermemory@latest login`).
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
