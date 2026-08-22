{
  config,
  lib,
  pkgs,
  dotfilesPath,
  ...
}:
let
  home = config.home.homeDirectory;

  # Shared with opencode/default.nix and sandbox.nix. ask/deny already come back fully rendered to Claude's
  # native Bash(x:*) syntax, credential denies folded in, so this file only wires perms.claudeCode in.
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
  };

  # This is a generated file, not a source file. It is generated from config.programs.claude-code.settings, not
  # claudeSettings above because sandbox.nix and auto-mode.nix merge their own keys (sandbox, autoMode) into the
  # same option
  #
  claudeSettingsJson = (pkgs.formats.json { }).generate "claude-code-settings.json" (
    config.programs.claude-code.settings
    // {
      "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    }
  );

  # Same convention as vscode/default.nix: a real, writable file inside the main checkout, not a store copy, so
  # both halves of what touches it show up in `git status`/`git diff`. Regenerated from claudeSettings on every
  # `home-manager switch`, and separately patched at runtime by rtk-hook.sh and homelab-network-hook.sh, both land
  # on this same file since it's the actual symlink target, not a copy. Shared with sandbox.nix's denyWrite via
  # permissions.nix, since the two files can't otherwise agree on the same path.
  claudeSettingsStatePath = perms.claudeCode.sandbox.paths.settingsFile;

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

    # Symlinked to ~/.claude/hooks/. Wired into settings.hooks below — dropping a script here does nothing on its own.
    hooksDir = ../hooks;

    skills = {
      nixpkgs-pr-checklist = ../skills/nixpkgs-pr-checklist;
    };

    settings = claudeSettings;
  };
}
