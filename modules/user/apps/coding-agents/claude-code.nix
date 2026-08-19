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

  # The other half of the credential policy (see #126): sandbox.filesystem.denyRead/denyWrite in
  # claude-sandbox.nix only confines the Bash subprocess. Read and Edit go through the permission
  # system instead, and Claude Code only consults Edit(path)/Read(path) rules — a Write(path) rule
  # is accepted but silently never checked, so Edit covers Write too here.
  #
  # `//path` is filesystem-root-absolute; a bare `/path` would anchor at the settings source
  # instead and match nothing. Directories need a `/**` suffix to reach files nested inside; a
  # bare file path doesn't.
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
      credentialPaths.files
      ++ [
        # Same reasoning as the sandbox half: the only credentialDenies entry nested under a
        # readable/writable directory, so the only one a sibling .bak could ride in on.
        "${home}/.claude/.credentials.json.bak"
      ]
    )
    ++ lib.concatMap dirDenyRules credentialPaths.dirs;

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

  claudeSettings = {
    model = "sonnet";

    includeCoAuthoredBy = false;
    theme = "dark";

    permissions = {
      # Chosen over bypassPermissions because entering auto mode drops broad allow rules granting arbitrary code execution, and because the classifier never sees tool results.
      defaultMode = "auto";

      # These hold in every mode, unlike allow rules and unlike autoMode.
      ask = map prefixRule gates.ask ++ map exactRule gates.askExact;
      # Hard tier only; the reversible ones are soft_deny in claude-automode.nix. credentialDenyRules
      # is the Read/Edit half of the credential policy — see its definition above.
      deny = map prefixRule gates.denyHard ++ credentialDenyRules;
    };

    # Keep the terminal tab labelled with the repo and branch Claude Code is working in, so a stack of tabs is readable at a glance. UserPromptSubmit covers branch switches mid-session; SessionStart covers the initial state and a resumed session.
    hooks = {
      UserPromptSubmit = [ terminalTitleHook ];
      SessionStart = [ terminalTitleHook ];
      PreToolUse = [ rtkHook ];
    };

    # Pre-registers each third-party marketplace so its plugin below resolves without an
    # interactive `/plugin marketplace add` first. claude-plugins-official needs no entry
    # here — it's the built-in Anthropic marketplace, known to Claude Code by name alone.
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

  # config.programs.claude-code.settings, not the local claudeSettings above: claude-sandbox.nix
  # and claude-automode.nix each merge their own keys (sandbox, autoMode) into the same option,
  # and the generated file needs all of it, not just what this module contributes. Doesn't
  # replicate the upstream module's disabledMcpjsonServers injection — this repo doesn't use
  # programs.mcp, so cfg.settings alone matches today. extraKnownMarketplaces is set directly
  # in claudeSettings above, so that one does flow through here like everything else.
  claudeSettingsJson = (pkgs.formats.json { }).generate "claude-code-settings.json" (
    config.programs.claude-code.settings
    // {
      "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    }
  );

  # Outside the repo and untracked: content gets regenerated from claudeSettings on every
  # `home-manager switch`, so there's no point versioning it.
  claudeSettingsStatePath = "${config.home.homeDirectory}/.local/state/claude-code/settings.json";

  # Must match the home.file keys the claude-code module itself uses (absolute, under configDir),
  # or home-manager sees two different attribute names resolving to the same target and refuses
  # to build ("Conflicting managed target files") instead of letting mkForce win.
  claudeConfigDir = config.programs.claude-code.configDir;
in
{
  # Out-of-store symlink to a real file in this repo: rtk init -g injects a short RTK.md pointer
  # into CLAUDE.md at runtime, which fails with EACCES if it's a symlink into the read-only Nix
  # store. force = true: rtk (or any tool) may replace the symlink with a plain file on write;
  # without force, the next switch would refuse to reclaim that path.
  home.file."${claudeConfigDir}/CLAUDE.md" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/code/dotfiles/modules/user/apps/coding-agents/AGENTS.md";
    force = true;
  };

  # Same problem as CLAUDE.md above, but settings.json has no source file to point at directly —
  # it's generated from the claudeSettings attrset. So generate it into the store as usual, then
  # copy it out to a writable state path and symlink ~/.claude/settings.json to that, so rtk init -g
  # can patch it (e.g. wiring its own hook) instead of hitting EACCES on the store path.
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
