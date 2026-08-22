{
  config,
  lib,
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
}
