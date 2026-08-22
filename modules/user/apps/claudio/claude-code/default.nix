# Claude Code: settings generation, the Seatbelt sandbox (see #121, #126), and the auto-mode classifier config,
# all in one file since nothing else contributes to programs.claude-code.settings. Background/investigation
# notes on the sandbox specifically: ../docs/sandbox-notes.md.
{
  config,
  lib,
  pkgs,
  dotfilesPath,
  ...
}:
let
  home = config.home.homeDirectory;

  # Shared with opencode/default.nix. ask/deny and the sandbox's filesystem/network both come back fully
  # rendered to Claude's native shape, this file only wires perms.claudeCode in.
  perms = import ../permissions.nix { inherit home lib dotfilesPath; };

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

    # ask/deny hold in every mode, unlike allow and autoMode.
    permissions = perms.claudeCode.permissions // {
      defaultMode = "auto";
    };

    hooks = {
      SessionStart = [ homelabNetworkHook ];
      PreToolUse = [ rtkHook ];
    };

    # Two ways to write a sandbox rule that silently does nothing: a trailing slash voids the entry on 2.1.222
    # (fixed in 2.1.224), and a glob like `$HOME/*` matches nothing and fails open.
    sandbox = {
      enabled = true;

      # Without both, the boundary is advisory: Claude may retry a blocked command unsandboxed, or continue if
      # Seatbelt is unavailable.
      allowUnsandboxedCommands = false;
      failIfUnavailable = true;

      autoAllowBashIfSandboxed = true;

      # docker/gh/fj policy: permissions.nix's claudeCode.sandbox.excludedCommands.
      inherit (perms.claudeCode.sandbox) excludedCommands;

      # Without this, `open -a <App>` fails with kLSUnknownErr: launching another app's process needs a
      # mach-lookup to RunningBoard/launchservicesd that the sandbox blocks.
      allowAppleEvents = true;

      network = perms.claudeCode.sandbox.network;
      filesystem = perms.claudeCode.sandbox.filesystem;
    };

    # Prose judged by a model, not enforcement: wording changes the outcome, and it only applies while the
    # session is in auto mode. Anything that must hold regardless goes in `permissions` above instead. A
    # profile's `autoMode.allow` can override a `soft_deny` from here, which is the only way a profile can
    # loosen anything inherited.
    autoMode = {
      # No hostnames, org names or topology: this repo mirrors publicly, and the built-in defaults already
      # trust the working repo's own remotes. Repo-specific context goes in that repo's CLAUDE.md, which the
      # classifier also reads.
      environment = [
        "$defaults"

        "Organization: personal single-developer setup, no company. Primary use of Claude Code: software development plus Nix-based infrastructure automation."

        "Internal package registry: none. Nix is the package manager, so its configured substituters are the expected download sources and flake inputs are fetched from their upstream forges."

        "Repository visibility: assume a repository is public unless something in the session shows otherwise, since several are mirrored publicly. Treat anything committed as published."

        "Additional context: this machine is a personal workstation, not a shared or production host."
      ];

      # Counterpart of permissions.nix's denySoft. Phrase as a category, never as an absolute: "under any
      # circumstances" makes it unoverridable and claudio-thebot needs to override this one. Do not mention
      # that stating intent clears it, which reads as permission to ignore the rule.
      soft_deny = [
        "$defaults"

        "Anything that appears publicly under the operator's name on a code forge, including opening or closing pull requests, submitting reviews, creating or editing issues, and commenting on any of them, is theirs to initiate rather than the agent's. Do not do these unprompted."
      ];
    };
  };

  # Generated straight from the local claudeSettings above: this is the only file that sets
  # programs.claude-code.settings, so there's no cross-file option merge to round-trip through.
  claudeSettingsJson = (pkgs.formats.json { }).generate "claude-code-settings.json" (
    claudeSettings
    // {
      "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    }
  );
in
{
  # Out-of-store: rtk init -g writes an RTK.md pointer into CLAUDE.md at runtime, which EACCESs against the read-only store. force = true lets rtk replace the symlink with a plain file without the next switch refusing to reclaim it.
  home.file."${config.programs.claude-code.configDir}/CLAUDE.md" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/modules/user/apps/claudio/AGENTS.md";
    force = true;
  };

  # Same EACCES problem as CLAUDE.md, but settings.json has no source file: generated into the store, then
  # copied to perms.paths.claudeSettingsFile (a real, writable file inside the main checkout, not a store copy,
  # same convention as vscode/default.nix) and symlinked there so rtk can patch it and a running session can
  # overwrite its own settings without a `just switch`. Must match the upstream module's own home.file key, or
  # home-manager sees two attrs targeting the same file and refuses to build instead of letting mkForce win.
  home.file."${config.programs.claude-code.configDir}/settings.json" = lib.mkForce {
    source = config.lib.file.mkOutOfStoreSymlink perms.paths.claudeSettingsFile;
    force = true;
  };

  home.activation.claudeCodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    install -Dm644 ${claudeSettingsJson} ${perms.paths.claudeSettingsFile}
  '';

  programs.claude-code = {
    enable = true;

    # Symlinked to ~/.claude/hooks/. Wired into settings.hooks above — dropping a script here does nothing on its own.
    hooksDir = ../hooks;

    skills = {
      nixpkgs-pr-checklist = ../skills/nixpkgs-pr-checklist;
    };

    settings = claudeSettings;
  };
}
