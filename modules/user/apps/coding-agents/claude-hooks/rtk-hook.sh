#!/usr/bin/env bash
set -euo pipefail

# rtk is installed as a home.packages entry (see default.nix) — always on
# PATH once activated. Off PATH before the first `just switch` / on a
# machine that hasn't run this home-manager config yet, pass the tool call
# through untouched rather than erroring it.
if ! command -v rtk >/dev/null 2>&1; then
  exit 0
fi

# First Bash call on a machine that has never run `rtk init -g`: bootstrap
# RTK.md + filters.toml. --no-patch skips the settings.json patch, since the
# PreToolUse hook wiring is already declared in claude-code.nix. Best-effort:
# a failed bootstrap must not block the actual command.
if [[ ! -f "$HOME/.claude/RTK.md" ]]; then
  # </dev/null: this is a PreToolUse hook, so the tool-call JSON is on our stdin and
  # `exec rtk hook claude` below needs it intact. Without the redirect, rtk init could
  # drain that stdin and leave the actual hook with truncated or empty input on the
  # first-ever Bash call of a fresh machine.
  rtk init -g --no-patch </dev/null >/dev/null 2>&1 || true
fi

exec rtk hook claude
