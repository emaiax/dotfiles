#!/usr/bin/env bash
set -euo pipefail

# Off PATH before the first `just switch`: pass the call through untouched, don't error it.
if ! command -v rtk >/dev/null 2>&1; then
  exit 0
fi

# First Bash call on a fresh machine: bootstrap RTK.md + filters.toml. --no-patch skips settings.json, already
# wired in claude-code/default.nix. </dev/null so `rtk init` can't drain the tool-call JSON the
# `exec rtk hook claude` below needs from our stdin. Best-effort.
if [[ ! -f "$HOME/.claude/RTK.md" ]]; then
  rtk init -g --no-patch </dev/null >/dev/null 2>&1 || true
fi

exec rtk hook claude
