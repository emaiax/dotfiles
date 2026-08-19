# The `claudio` profile: Obsidian vault work, layered over claude-sandbox.nix via `--settings` (see #121).
#
# No vault path appears below on purpose. The vault is reached only through obsidian-cli, which means Obsidian.app does the file access and nothing here can scope it. Needs Obsidian running.
#
# Otherwise identical to the default profile: full read/write in ~/code, same ask/deny gates. This profile only adds the vault socket.
{
  config,
  pkgs,
  ...
}:
let
  home = config.home.homeDirectory;

  settings = {
    sandbox = {
      # Unix sockets are governed separately from domains, so this is needed even though the network is otherwise open.
      network.allowUnixSockets = [ "${home}/.obsidian-cli.sock" ];

      filesystem = {
        # allowUnixSockets covers connecting, not stat'ing the path.
        allowRead = [ "${home}/.obsidian-cli.sock" ];
      };
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
