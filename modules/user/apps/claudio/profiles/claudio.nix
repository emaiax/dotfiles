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

    # This is an "auto" profile (not the yolo claudio-thebot): perms.claudeCode.user is the full ask/deny
    # bundle with hardDeny already on (permissions.nix). ask/deny hold in every mode, unlike allow and autoMode.
    # defaultMode lives here, not in the shared base (claude-code/default.nix): this profile is what opts into
    # "auto" mode, not every plain `claude` session.
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
