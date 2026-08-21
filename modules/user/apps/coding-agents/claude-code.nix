{
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.home.homeDirectory;

  # Shared with opencode.nix.
  gates = import ./gates.nix;

  # `Bash(x:*)` matches any arguments; `Bash(x)` matches only that literal invocation.
  prefixRule = cmd: "Bash(${cmd}:*)";
  exactRule = cmd: "Bash(${cmd})";

  # rtk's PreToolUse hook rewrites recognized commands to `rtk <cmd>`, and permission rules match against that rewritten string — so a bare-command gate is silently defeated for anything rtk rewrites. A twin per gate rather than a fixed list, since rtk's rewrite inventory can grow.
  withRtkTwin =
    cmds:
    lib.concatMap (cmd: [
      cmd
      "rtk ${cmd}"
    ]) cmds;

  # Read/Edit half of the credential policy (see #126) — claude-sandbox.nix's denyRead/denyWrite only confines Bash. Write(path) rules are silently never checked, so Edit covers Write too.
  #
  # `//path` is filesystem-root-absolute; `/path` matches nothing. Dirs need `/**` for nested files.
  credentialPaths = import ./credential-paths.nix home;
  absRule = path: lib.removePrefix "/" path;
  fileDenyRules = path: [
    "Read(//${absRule path})"
    "Edit(//${absRule path})"
  ];
  dirDenyRules = path: [
    "Read(//${absRule path}/**)"
    "Edit(//${absRule path}/**)"
  ];
  credentialDenyRules =
    lib.concatMap fileDenyRules (
      credentialPaths.files ++ map (p: "${p}.bak") credentialPaths.bakCarveouts
    )
    ++ lib.concatMap dirDenyRules credentialPaths.dirs;

  # `bash "path"`, not direct exec: hooksDir symlinks don't reliably keep the executable bit, and a non-executable hook fails silently.
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

  # Separate from rtkHook: this only needs to run once per session, not on every Bash call.
  homelabNetworkHook = {
    hooks = [
      {
        type = "command";
        command = ''bash "$HOME/.claude/hooks/homelab-network-hook.sh"'';
      }
    ];
  };

  claudeSettings = {
    model = "sonnet";

    includeCoAuthoredBy = false;
    theme = "dark";

    permissions = {
      # auto over bypassPermissions: bypass drops broad allow rules (arbitrary code execution), and its classifier never sees tool results.
      defaultMode = "auto";

      # ask/deny hold in every mode, unlike allow and autoMode.
      ask = map prefixRule (withRtkTwin gates.ask) ++ map exactRule (withRtkTwin gates.askExact);
      # Hard tier only; reversible ones are soft_deny in claude-automode.nix.
      deny = map prefixRule (withRtkTwin gates.denyHard) ++ credentialDenyRules;
    };

    hooks = {
      SessionStart = [ homelabNetworkHook ];
      PreToolUse = [ rtkHook ];
    };

    # Pre-registers each third-party marketplace so its plugin below resolves without an interactive `/plugin marketplace add` first; claude-plugins-official is built-in.
    extraKnownMarketplaces = {
      thedotmack = {
        source = {
          source = "github";
          repo = "thedotmack/claude-mem";
        };
      };
      obsidian-skills = {
        source = {
          source = "github";
          repo = "kepano/obsidian-skills";
        };
      };
    };

    enabledPlugins = {
      # claude-mem: semantic memory across sessions (see claude-mem.nix).
      "claude-mem@thedotmack" = true;
      "superpowers@claude-plugins-official" = true;
      # Obsidian Flavored Markdown, Bases, JSON Canvas and the `obsidian` CLI: https://github.com/kepano/obsidian-skills
      "obsidian@obsidian-skills" = true;
    };
  };

  # config.programs.claude-code.settings, not claudeSettings above: claude-sandbox.nix and claude-automode.nix merge their own keys (sandbox, autoMode) into the same option.
  claudeSettingsJson = (pkgs.formats.json { }).generate "claude-code-settings.json" (
    config.programs.claude-code.settings
    // {
      "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    }
  );

  # Outside the repo and untracked: content gets regenerated from claudeSettings on every `home-manager switch`, so there's no point versioning it.
  claudeSettingsStatePath = "${config.home.homeDirectory}/.local/state/claude-code/settings.json";

  # Must match the upstream module's own home.file keys (absolute, under configDir), or home-manager sees two attrs targeting the same file and refuses to build instead of letting mkForce win.
  claudeConfigDir = config.programs.claude-code.configDir;

  # Same convention as vscode/default.nix and iterm2/default.nix: always the main checkout, deliberately, not wherever this was evaluated from.
  agentsSourcePath = "${home}/code/dotfiles/modules/user/apps/coding-agents/AGENTS.md";
in
{
  # Out-of-store: rtk init -g writes an RTK.md pointer into CLAUDE.md at runtime, which EACCESs against the read-only store. force = true lets rtk replace the symlink with a plain file without the next switch refusing to reclaim it.
  home.file."${claudeConfigDir}/CLAUDE.md" = {
    source = config.lib.file.mkOutOfStoreSymlink agentsSourcePath;
    force = true;
  };

  # Same EACCES problem as CLAUDE.md, but settings.json has no source file — generated into the store, then copied to a writable state path and symlinked there so rtk can patch it.
  home.file."${claudeConfigDir}/settings.json" = lib.mkForce {
    source = config.lib.file.mkOutOfStoreSymlink claudeSettingsStatePath;
    force = true;
  };

  home.activation.claudeCodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    install -Dm644 ${claudeSettingsJson} ${claudeSettingsStatePath}
  '';

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

    settings = claudeSettings;
  };
}
