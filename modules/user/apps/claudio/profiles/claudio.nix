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
  claudioCfg = config.programs.claudio;

  perms = import ../permissions.nix {
    inherit home lib;
    inherit (claudioCfg) permissions;
  };

  settings = {
    sandbox = {
      enabled = false; # disable sandboxing for now, blocks ssh'ing into homelab guests

      filesystem.allowRead = [ obsidianSocket ];
      network.allowUnixSockets = [ obsidianSocket ];
    };

    # An "auto" profile (not yolo like claudio-thebot): defaultMode lives here since this is what opts into
    # "auto" mode, not every plain `claude` session (docs/sandbox-notes.md).
    permissions = perms.forProfile "claudio";
  };

  settingsFile = (pkgs.formats.json { }).generate "claudio-settings.json" settings;
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "claudio";
      runtimeInputs = [
        config.programs.claude-code.package
        config.programs.antigravity-cli.package
        config.programs.opencode.package
      ];
      text = ''
        default_backend="${config.programs.claudio.backend}"
        backend="$default_backend"

        if [[ -n "''${CLAUDIO_BACKEND:-}" ]]; then
          backend="$CLAUDIO_BACKEND"
        fi

        if [[ $# -gt 0 ]]; then
          case "$1" in
            --agy)
              backend="agy"
              shift
              ;;
            --claude|--claude-code)
              backend="claude-code"
              shift
              ;;
            --opencode)
              backend="opencode"
              shift
              ;;
            --backend|-b)
              if [[ $# -lt 2 ]]; then
                echo "claudio: missing argument for $1" >&2
                exit 1
              fi
              backend="$2"
              shift 2
              ;;
            --backend=*)
              backend="''${1#*=}"
              shift
              ;;
          esac
        fi

        case "$backend" in
          agy)
            exec agy "$@"
            ;;
          claude-code)
            exec claude --settings ${settingsFile} "$@"
            ;;
          opencode)
            exec opencode "$@"
            ;;
          *)
            echo "claudio: unknown backend '$backend' (supported: agy, claude-code, opencode)" >&2
            exit 1
            ;;
        esac
      '';
    })
  ];
}
