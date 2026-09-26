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

    # default permissions with auto mode
    permissions = perms.claudeCode.permissions // {
      defaultMode = "auto";
    };
  };

  settingsFile = (pkgs.formats.json { }).generate "claudio-settings.json" settings;
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      runtimeInputs = [
        config.programs.antigravity-cli.package
        config.programs.claude-code.package
        config.programs.opencode.package
      ];

      name = "claudio";
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
            has_print=0
            prompt=""
            extra_args=()
            while [[ $# -gt 0 ]]; do
              case "$1" in
                -p|--print)
                  has_print=1
                  if [[ $# -lt 2 ]]; then
                    echo "claudio: missing argument for $1" >&2
                    exit 1
                  fi
                  prompt="$2"
                  shift 2
                  ;;
                --print=*)
                  has_print=1
                  prompt="''${1#*=}"
                  shift
                  ;;
                *)
                  extra_args+=("$1")
                  shift
                  ;;
              esac
            done

            if [[ $has_print -eq 1 ]]; then
              exec opencode run "''${extra_args[@]}" "$prompt"
            else
              exec opencode "''${extra_args[@]}"
            fi
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
