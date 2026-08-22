{
  config,
  lib,
  pkgs,
  dotfilesPath,
  ...
}:
let
  home = config.home.homeDirectory;

  # Shared with claude-code.nix and sandbox.nix. permission (including bash's dag-entry rendering) comes back
  # fully assembled, this file only wires it in.
  perms = import ../permissions.nix { inherit home lib dotfilesPath; };

  # Shared with claude-code.nix.
  settingsValues = import ../settings.nix;

  # Generated from config.programs.opencode.settings (the merged option), not the settings block below directly,
  # same reasoning as claude-code.nix's claudeSettingsJson.
  opencodeSettingsJson = (pkgs.formats.json { }).generate "opencode-settings.json" (
    config.programs.opencode.settings
  );

  # Same convention as claude-code.nix's claudeSettingsStatePath: a real, writable file inside the main checkout,
  # not a store copy, so a running session can overwrite its own settings (install a plugin, tweak config)
  # without a `just switch`, and both halves of what touches it show up in `git status`/`git diff`.
  opencodeSettingsStatePath = perms.paths.opencodeSettingsFile;
in
{
  programs.opencode = {
    enable = true;

    # Personal agent operating context as the global AGENTS.md; same source as programs.claude-code's
    # ~/.claude/CLAUDE.md.
    context = ../AGENTS.md;

    skills = {
      # Shared vendored skills dir; same source as programs.claude-code.skills.
      nixpkgs-pr-checklist = ../skills/nixpkgs-pr-checklist;
    };

    settings = settingsValues.opencode // {
      inherit (perms.opencode) permission;
    };

    tui = {
      # Respect the system appearance setting on macOS.
      theme = "system";
    };
  };

  # Must match the upstream module's own home.file key, or home-manager sees two attrs targeting the same file
  # and refuses to build instead of letting mkForce win.
  home.file."${config.xdg.configHome}/opencode/opencode.json" = lib.mkForce {
    source = config.lib.file.mkOutOfStoreSymlink opencodeSettingsStatePath;
    force = true;
  };

  home.activation.opencodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    install -Dm644 ${opencodeSettingsJson} ${opencodeSettingsStatePath}
  '';
}
