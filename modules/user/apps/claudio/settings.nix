# Static settings values for each backend: model choice, theme, plugins. Not permissions (permissions.nix), not
# hooks or the sandbox/autoMode merge, those are composed inside each backend's own module since they're built
# from other data, not plain preferences.
{
  claudeCode = {
    model = "sonnet";

    includeCoAuthoredBy = false;
    theme = "dark";

    extraKnownMarketplaces = {
      obsidian-skills = {
        source = {
          source = "github";
          repo = "kepano/obsidian-skills";
        };
      };
      thedotmack = {
        source = {
          source = "github";
          repo = "thedotmack/claude-mem";
        };
      };
    };

    enabledPlugins = {
      "claude-mem@thedotmack" = true; # semantic memory across sessions
      "obsidian@obsidian-skills" = true; # obsidian markdown, bases, JSON Canvas and `obsidian` CLI
      "superpowers@claude-plugins-official" = true; # superpowers: code analysis, refactoring, and generation
    };
  };

  opencode = {
    model = "anthropic/claude-opus-5";
    # Cheap/routine tasks (title generation, etc.) skip the primary model.
    small_model = "anthropic/claude-haiku-4-5-20251001";

    # The package is managed by Nix, so this never auto-installs, it only checks and prints a notice, which is
    # how we know to bump the flake input instead of drifting out of sync with it.
    autoupdate = "notify";

    # Disable remote sharing by default.
    share = "disabled";

    # Match the shell configured in this repo.
    shell = "zsh";

    # Per-turn undo of file edits (opencode default; explicit for clarity).
    snapshot = true;

    compaction.auto = true;

    # Plugins loaded at startup. superpowers: brainstorming, planning, and execution workflow skills. supermemory:
    # persistent cross-session memory (requires `bunx opencode-supermemory@latest login`).
    plugin = [
      "superpowers@git+https://github.com/obra/superpowers.git"
      "opencode-supermemory"
    ];
  };
}
