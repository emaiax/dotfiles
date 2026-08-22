{
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.home.homeDirectory;

  # Shared with opencode.nix.
  gates = import ../agent-shared/gates.nix;

  # `Bash(x:*)` matches any arguments; `Bash(x)` matches only that literal invocation.
  prefixRule = cmd: "Bash(${cmd}:*)";
  exactRule = cmd: "Bash(${cmd})";

  # rtk's PreToolUse hook rewrites recognized commands to `rtk <cmd>`, and permission rules match against that rewritten
  # string, so a bare-command gate is silently defeated for anything rtk rewrites. A twin per gate rather than a fixed
  # list, since rtk's rewrite inventory can grow.
  withRtkTwin =
    cmds:
    lib.concatMap (cmd: [
      cmd
      "rtk ${cmd}"
    ]) cmds;

  # Read/Edit is only half of the credential policy: denyRead/denyWrite only confines Bash in sandbox. Write(path) rules
  # are silently never checked, so Edit covers Write too.
  #
  # `//path` is filesystem-root-absolute;
  # `/path` matches nothing.
  #
  # Dirs need `/**` for nested files.
  #
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
        statusMessage = "Applying RTK token-reduction filter";
      }
    ];
  };

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
      defaultMode = "auto";

      # ask/deny hold in every mode, unlike allow and autoMode.
      ask = map prefixRule (withRtkTwin gates.ask) ++ map exactRule (withRtkTwin gates.askExact);

      # hard tier only; reversible ones are soft_deny in claude-automode.nix
      deny = map prefixRule (withRtkTwin gates.denyHard) ++ credentialDenyRules;
    };

    hooks = {
      SessionStart = [ homelabNetworkHook ];
      PreToolUse = [ rtkHook ];
    };

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

  # This is a generated file, not a source file. It is generated from config.programs.claude-code.settings, not
  # claudeSettings above because claude-sandbox.nix and claude-automode.nix merge their own keys (sandbox, autoMode)
  # into the same option
  #
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

  # same convention as vscode/default.nix and iterm2/default.nix: always the main checkout, deliberately, not wherever this was evaluated from
  agentsSourcePath = "${home}/code/dotfiles/modules/user/apps/agent-shared/AGENTS.md";
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
    hooksDir = ./hooks;

    skills = {
      nixpkgs-pr-checklist = ../agent-shared/skills/nixpkgs-pr-checklist;
    };

    settings = claudeSettings;
  };
}
