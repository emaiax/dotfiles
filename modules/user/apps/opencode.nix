{ ... }:
{
  programs.opencode = {
    enable = true;

    # Publish project-wide conventions as the global AGENTS.md context.
    context = ../../../CLAUDE.md;

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
