{ ... }:
let
  # Invoked through `bash` rather than executed: the home-manager module writes
  # hooksDir files as plain symlinks, so the executable bit is not guaranteed to
  # survive. A hook that is not executable fails silently.
  terminalTitleHook = {
    hooks = [
      {
        type = "command";
        command = ''bash "$HOME/.claude/hooks/terminal-title.sh"'';
      }
    ];
  };
in
{
  # Personal agent operating context, not the dotfiles project docs.
  home.file.".claude/CLAUDE.md".source = ./AGENTS.md;

  programs.claude-code = {
    enable = true;

    # Symlinked to ~/.claude/hooks/. Wired into settings.hooks below — dropping a
    # script here does nothing on its own.
    hooksDir = ./claude-hooks;

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

      # Keep the terminal tab labelled with the repo and branch Claude Code is
      # working in, so a stack of tabs is readable at a glance. UserPromptSubmit
      # covers branch switches mid-session; SessionStart covers the initial state
      # and a resumed session.
      hooks = {
        UserPromptSubmit = [ terminalTitleHook ];
        SessionStart = [ terminalTitleHook ];
      };

      enabledPlugins = {
        # claude-mem: semantic memory across sessions (see claude-mem.nix).
        "claude-mem@thedotmack" = true;
        "superpowers@claude-plugins-official" = true;
      };
    };
  };
}
