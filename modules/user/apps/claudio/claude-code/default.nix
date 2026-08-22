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

  # Shared with opencode/default.nix.
  settingsValues = import ../settings.nix;

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

  claudeSettings = settingsValues.claudeCode // {
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

  # Same convention as vscode/default.nix: a real, writable file inside the main checkout, not a store copy, so
  # both halves of what touches it show up in `git status`/`git diff`. Regenerated from claudeSettings on every
  # `home-manager switch`, and separately patched at runtime by rtk-hook.sh and homelab-network-hook.sh, both
  # land on this same file since it's the actual symlink target, not a copy.
  claudeSettingsStatePath = perms.paths.claudeSettingsFile;

  # Must match the upstream module's own home.file keys (absolute, under configDir), or home-manager sees two attrs targeting the same file and refuses to build instead of letting mkForce win.
  claudeConfigDir = config.programs.claude-code.configDir;

  # same convention as vscode/default.nix and iterm2/default.nix: always the main checkout (dotfilesPath, from
  # nix/inventory.nix's repo), deliberately, not wherever this was evaluated from
  agentsSourcePath = "${dotfilesPath}/modules/user/apps/claudio/AGENTS.md";
in
{
  # Out-of-store: rtk init -g writes an RTK.md pointer into CLAUDE.md at runtime, which EACCESs against the read-only store. force = true lets rtk replace the symlink with a plain file without the next switch refusing to reclaim it.
  home.file."${claudeConfigDir}/CLAUDE.md" = {
    source = config.lib.file.mkOutOfStoreSymlink agentsSourcePath;
    force = true;
  };

  # Same EACCES problem as CLAUDE.md, but settings.json has no source file: generated into the store, then copied to claudeSettingsStatePath and symlinked there so rtk can patch it.
  home.file."${claudeConfigDir}/settings.json" = lib.mkForce {
    source = config.lib.file.mkOutOfStoreSymlink claudeSettingsStatePath;
    force = true;
  };

  home.activation.claudeCodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    install -Dm644 ${claudeSettingsJson} ${claudeSettingsStatePath}
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
