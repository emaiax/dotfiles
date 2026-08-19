{ lib, ... }:
let
  # Shared with opencode.nix — see gates.nix for why this list is centralised.
  gates = import ./gates.nix;

  # Claude's Bash rules are prefix matches: `Bash(git push:*)` covers any arguments, `Bash(git checkout .)` matches only that literal invocation.
  prefixRule = cmd: "Bash(${cmd}:*)";
  exactRule = cmd: "Bash(${cmd})";

  # Invoked through `bash` rather than executed: the home-manager module writes hooksDir files as plain symlinks, so the executable bit is not guaranteed to survive. A hook that is not executable fails silently.
  terminalTitleHook = {
    hooks = [
      {
        type = "command";
        command = ''bash "$HOME/.claude/hooks/terminal-title.sh"'';
      }
    ];
  };

  rtkHook = {
    matcher = "Bash";
    hooks = [
      {
        type = "command";
        command = ''bash "$HOME/.claude/hooks/rtk-hook.sh"'';
        statusMessage = "Applying rtk token-reduction filter...";
      }
    ];
  };
in
{
  # Personal agent operating context, not the dotfiles project docs.
  home.file.".claude/CLAUDE.md".source = ./AGENTS.md;

  programs.claude-code = {
    enable = true;

    # Symlinked to ~/.claude/hooks/. Wired into settings.hooks below — dropping a script here does nothing on its own.
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

      permissions = {
        # `auto` replaces the human prompt with a classifier that reviews each non-trivial action. Chosen over `bypassPermissions` for two reasons beyond the obvious: entering auto mode *drops* broad allow rules that grant arbitrary code execution (`Bash(*)`, `Bash(python*)`, package runners) and restores them on exit, so a careless allow in some repo's committed settings can't escalate; and the classifier never sees tool results, so hostile content in a file or web page can't address it. See issue #121 for the full comparison against today's `claude-trust`.
        defaultMode = "auto";

        # Deny rules hold in every mode, including `bypassPermissions` — only allow rules go inert there — so these gates survive `claude-remote` too. Rendered from the same list opencode.nix uses.
        ask = map prefixRule gates.ask ++ map exactRule gates.askExact;
        # Only the hard tier. The reversible publication commands live in claude-automode.nix's soft_deny instead, so claudio-thebot can carve out an exception — permissions.deny offers no way to grant one.
        deny = map prefixRule gates.denyHard;
      };

      # Keep the terminal tab labelled with the repo and branch Claude Code is working in, so a stack of tabs is readable at a glance. UserPromptSubmit covers branch switches mid-session; SessionStart covers the initial state and a resumed session.
      hooks = {
        UserPromptSubmit = [ terminalTitleHook ];
        SessionStart = [ terminalTitleHook ];
        PreToolUse = [ rtkHook ];
      };

      enabledPlugins = {
        # claude-mem: semantic memory across sessions (see claude-mem.nix).
        "claude-mem@thedotmack" = true;
        "superpowers@claude-plugins-official" = true;
      };
    };
  };
}
