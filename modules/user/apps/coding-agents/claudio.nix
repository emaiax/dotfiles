# The `claudio` profile: Obsidian vault work, layered over claude-sandbox.nix via `--settings`
# (see #121). Also used for general ~/code work now — `code/work` is the one carve-out kept
# denied (see denyWrite below).
#
# No vault path appears below on purpose. The vault is reached only through obsidian-cli, which means Obsidian.app does the file access and nothing here can scope it. Needs Obsidian running.
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

        # `--settings` concatenates arrays, so a profile can only widen the inherited scope. denyWrite is the one exception. Everything else under ~/code inherits write access from claude-sandbox.nix's base allowWrite; this one subtree stays out of reach even from this profile.
        denyWrite = [ "${home}/code/work" ];
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
        # cwd is always writable, so launching from anywhere in $HOME that no denyWrite covers would quietly make that directory writable. An empty scratch dir is the fix.
        scratch="''${XDG_CACHE_HOME:-$HOME/.cache}/claudio/cwd"
        mkdir -p "$scratch"
        cd "$scratch"

        exec claude --settings ${settingsFile} "$@"
      '';
    })
  ];
}
