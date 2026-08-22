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
  # Must match the upstream module's own home.file key, or home-manager sees two attrs targeting the same file
  # and refuses to build instead of letting mkForce win.
  home.file."${config.xdg.configHome}/opencode/opencode.json" = lib.mkForce {
    source = config.lib.file.mkOutOfStoreSymlink opencodeSettingsStatePath;
    force = true;
  };

  home.activation.opencodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    install -Dm644 ${opencodeSettingsJson} ${opencodeSettingsStatePath}
  '';

  programs.opencode = {
    enable = true;

    # Personal agent operating context as the global AGENTS.md; same source as programs.claude-code's claudio AGENTS.md
    context = ../AGENTS.md;

    skills = {
      nixpkgs-pr-checklist = ../skills/nixpkgs-pr-checklist;
    };

    # A separate option, not a settings.json key: the upstream module writes this to its own tui.json instead.
    tui.theme = "system"; # respect the system appearance setting on macOS.

    settings = {
      model = "anthropic/claude-opus-5";
      small_model = "anthropic/claude-haiku-4-5-20251001"; # cheap/routine tasks (title generation, etc.), skip the primary model

      autoupdate = "notify"; # managed by Nix, so this never auto-updates, it only checks and prints a notice instead
      share = "disabled"; # disable remote sharing by default
      shell = "zsh"; # match the shell configured in this repo
      snapshot = true; # per-turn undo of file edits (opencode default; explicit for clarity).
      compaction.auto = true;

      # Plugins loaded at startup. superpowers: brainstorming, planning, and execution workflow skills.
      # supermemory: persistent cross-session memory (requires `bunx opencode-supermemory@latest login`).
      plugin = [
        "superpowers@git+https://github.com/obra/superpowers.git"
        "opencode-supermemory"
      ];

      permission = perms.opencode.permission;
    };
  };
}
