# The `claude-yolo` profile: no Seatbelt sandbox, no permission prompts, layered over the default profile via
# `--settings` plus `--dangerously-skip-permissions`. See docs/sandbox-notes.md's "claude-yolo" sections.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.home.homeDirectory;
  claudioCfg = config.programs.claudio;

  perms = import ../permissions.nix {
    inherit home lib;
    inherit (claudioCfg) permissions;
  };

  settings = {
    sandbox.enabled = false;
    permissions = perms.claudeCode.credentialDenyOnly;
  };

  settingsFile = (pkgs.formats.json { }).generate "claude-yolo-settings.json" settings;
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "claude-yolo";
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
                echo "claude-yolo: missing argument for $1" >&2
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
            exec env CLAUDIO_DANGEROUSLY_SKIP_PERMISSIONS=1 agy --dangerously-skip-permissions "$@"
            ;;
          claude-code)
            exec claude --dangerously-skip-permissions --settings ${settingsFile} "$@"
            ;;
          opencode)
            exec opencode --auto "$@"
            ;;
          *)
            echo "claude-yolo: unknown backend '$backend' (supported: agy, claude-code, opencode)" >&2
            exit 1
            ;;
        esac
      '';
    })
  ];
}
