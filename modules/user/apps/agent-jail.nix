# modules/agent-jail.nix
#
#   ┌─────────────────────────────────────────────────────┐
#   │  agent-jail — filesystem jail for AI agents         │
#   │                                                     │
#   │  Every run is a micro-VM (apple/container) that     │
#   │  only sees the allowlist below. True default-deny:  │
#   │  the rest of the vault does not exist in the jail.  │
#   └─────────────────────────────────────────────────────┘
#
# Usage:
#   agent-jail              # Claude Code inside the jail
#   agent-jail shell        # explore the jail from within (bash)
#   agent-jail mounts       # print the active allowlist
#   agent-jail <cmd> ...    # arbitrary command in the image
#
# Requirement outside Nix (native Darwin binary, not in nixpkgs):
#   brew install container
#
# Validated by test-agent-jail.sh (21/21) on macOS 26 + container 1.1.0.

{
  config,
  pkgs,
  lib,
  ...
}:

let
  vault = "${config.home.homeDirectory}/Obsidian/emaiax";
  image = "docker.io/library/node:22";
  npmCacheVolume = "agent-jail-npm-cache";

  # ═══ THE ALLOWLIST — the only part you ever touch ════════════════
  #
  # Each entry becomes a mount at /jail/<path>, preserving the
  # original directory name (Obsidian links resolve the same way
  # inside and outside the jail).
  #
  # rw = false  →  --mount ...,readonly   (agent can read, not touch)
  # rw = true   →  --volume               (agent can read and write)
  #
  # ORDER MATTERS: an rw mount inside a ro directory must come
  # AFTER its parent — the later mount punches the writable hole.
  allowlist = [
    {
      path = "10 - projects";
      rw = false;
    }
    {
      path = "30 - resources";
      rw = false;
    }
    {
      path = "99 - metadata";
      rw = false;
    }
    {
      path = "99 - metadata/99.04 - ai";
      rw = true;
    }
  ];
  # ═════════════════════════════════════════════════════════════════

  mkMount =
    { path, rw }:
    if rw then
      ''--volume "${vault}/${path}:/jail/${path}"''
    else
      ''--mount "source=${vault}/${path},target=/jail/${path},readonly"'';

  mountArgs = lib.concatStringsSep " \\\n          " (map mkMount allowlist);

  mountTable = lib.concatStringsSep "\n" (
    map (m: "  ${if m.rw then "rw" else "ro"}  ${vault}/${m.path}") allowlist
  );
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "agent-jail";
      runtimeInputs = [ ];
      text = ''
        usage() {
          echo "agent-jail — run AI agents that only see the vault allowlist"
          echo ""
          echo "  agent-jail              Claude Code inside the jail"
          echo "  agent-jail shell        bash inside the jail (see the world as the agent does)"
          echo "  agent-jail mounts       print the active allowlist"
          echo "  agent-jail <cmd>...     arbitrary command in the image"
        }

        case "''${1:-}" in
          -h|--help|help)
            usage
            exit 0
            ;;
          mounts)
            echo "allowlist (image: ${image}):"
            printf '%s\n' ${lib.escapeShellArg mountTable}
            exit 0
            ;;
          shell)
            shift
            set -- bash
            ;;
        esac

        if ! command -v container >/dev/null 2>&1; then
          echo "error: apple/container not installed (brew install container)" >&2
          exit 1
        fi

        if ! container system status >/dev/null 2>&1; then
          echo "agent-jail: starting container service..." >&2
          container system start
        fi

        # persistent npm cache — without it every run re-downloads claude-code
        container volume create ${npmCacheVolume} >/dev/null 2>&1 || true

        # no args: Claude Code
        if [ $# -eq 0 ]; then
          set -- npx -y @anthropic-ai/claude-code
        fi

        exec container run -it --rm \
          ${mountArgs} \
          --volume "$HOME/.claude:/root/.claude" \
          --volume "$HOME/.claude.json:/root/.claude.json" \
          --volume ${npmCacheVolume}:/root/.npm \
          --workdir /jail \
          ${image} \
          "$@"
      '';
    })
  ];
}
