# The `claudio` profile: Obsidian vault work, layered over the base settings via `--settings`. Needs Obsidian
# running: obsidian-cli is the only thing that reaches the vault, so no vault path is scoped here.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  obsidianSocket = "${home}/.obsidian-cli.sock";
  home = config.home.homeDirectory;

  perms = import ../permissions.nix { inherit home lib; };

  settings = {
    sandbox = {
      enabled = false; # disable sandboxing for now, blocks ssh'ing into homelab guests

      filesystem.allowRead = [ obsidianSocket ];
      network.allowUnixSockets = [ obsidianSocket ];
    };

    # An "auto" profile (not yolo like claudio-thebot): defaultMode lives here since this is what opts into
    # "auto" mode, not every plain `claude` session (docs/sandbox-notes.md).
    permissions = perms.claudeCode.user // {
      defaultMode = "auto";
    };
  };

  settingsFile = (pkgs.formats.json { }).generate "claudio-settings.json" settings;
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "claudio";
      runtimeInputs = [ config.programs.claude-code.package ];
      text = ''
        exec claude --settings ${settingsFile} "$@"
      '';
    })
  ];
}
