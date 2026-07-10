{ ... }:
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
      # The package is managed by Nix; disable self-updates.
      autoupdate = false;

      # Disable remote sharing by default.
      share = "disabled";

      # Match the shell configured in this repo.
      shell = "zsh";

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
