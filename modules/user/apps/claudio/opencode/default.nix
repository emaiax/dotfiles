{
  claudioPath,
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.home.homeDirectory;

  # Shared with claude-code.nix and sandbox.nix. permission (including bash's dag-entry rendering) comes back
  # fully assembled, this file only wires it in.
  perms = import ../permissions.nix { inherit home lib; };

  opencodeSettingsJson = (pkgs.formats.json { }).generate "opencode-settings.json" (
    config.programs.opencode.settings
  );
in
{
  home.file."${config.xdg.configHome}/opencode/opencode.json" = lib.mkForce {
    source = config.lib.file.mkOutOfStoreSymlink "${claudioPath}/opencode/settings.json";
    force = true;
  };

  # Seed only, never overwrite: once this file exists it's a normal writable repo file, and a session may have
  # edited it since the last switch (installed a plugin, etc.). Delete it to reset to the Nix-declared baseline.
  home.activation.opencodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ ! -e "${claudioPath}/opencode/settings.json" ]]; then
      install -Dm644 ${opencodeSettingsJson} "${claudioPath}/opencode/settings.json"
    fi
  '';

  # Symlinked straight to the checkout rather than via programs.opencode.context/skills: those options read the
  # path at eval time (lib.pathIsDirectory), which is both a pure-eval violation for a path outside the flake's
  # own tree and, even inside it, a read-only nix store copy. This keeps them live-editable without `just switch`.
  home.file."${config.xdg.configHome}/opencode/AGENTS.md" = {
    source = config.lib.file.mkOutOfStoreSymlink "${claudioPath}/AGENTS.md";
    force = true;
  };

  home.file."${config.xdg.configHome}/opencode/skills" = {
    source = config.lib.file.mkOutOfStoreSymlink "${claudioPath}/skills";
    force = true;
  };

  programs.opencode = {
    enable = true;

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
