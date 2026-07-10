{ ... }:
{
  # Personal agent operating context, not the dotfiles project docs.
  home.file.".claude/CLAUDE.md".source = ./AGENTS.md;

  programs.claude-code = {
    enable = true;

    rules = {
      git-and-pr-conventions = ''
        ---
        description: "Git and PR conventions"
        # no paths: = loads every session
        ---

        # Commits

        - Conventional commits: feat: fix: chore:
        - Imperative mood: "Fix bug" not "Fixed bug"
        - Never add `Co-authored-by` to commits

        # Always branch first

        - Never work on main. Remind me if I haven't branched yet
      '';
      nix-conventions = ''
        ---
        description: "Nix devshells and conventions"
        # no paths: = loads every session
        ---

        - Use nix develop to enter a devshell
        - Only run commands in the devshell
      '';
    };

    skills = {
      # Shared vendored skills dir; same source as programs.opencode.skills.
      nixpkgs-pr-checklist = ./skills/nixpkgs-pr-checklist;
    };

    settings = {
      model = "sonnet";

      includeCoAuthoredBy = false;
      theme = "dark";

      enabledPlugins = {
        # claude-mem: semantic memory across sessions (see claude-mem.nix).
        "claude-mem@thedotmack" = true;
        "superpowers@claude-plugins-official" = true;
      };
    };
  };
}
