# The `claudio` profile: Obsidian vault work, layered over the base settings via `--settings`.
# Otherwise identical to the default profile, this only adds the vault socket.
#
# No vault path below on purpose: the vault is reached only through obsidian-cli, so Obsidian.app does the file
# access and nothing here can scope it. Needs Obsidian running.
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

    # This is an "auto" profile (not a yolo one): hardDeny = true opts into the irreversible-command tier.
    # See the comment above `denyHard` in permissions.nix's `policy.commands` for why this is opt-in.
    permissions = perms.mkClaudeCodePermissions {
      inherit (perms) policy;
      hardDeny = true;
    };
  };

  settingsFile = (pkgs.formats.json { }).generate "claudio-settings.json" settings;
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "claudio";
      runtimeInputs = [ pkgs.claude-code ];
      text = ''
        exec claude --settings ${settingsFile} "$@"
      '';
    })
  ];
}
