#!/usr/bin/env bash
set -euo pipefail

# rtk is installed as a home.packages entry (see default.nix) — always on
# PATH once activated. Off PATH before the first `just switch` / on a
# machine that hasn't run this home-manager config yet, pass the tool call
# through untouched rather than erroring it.
if ! command -v rtk >/dev/null 2>&1; then
  exit 0
fi

exec rtk hook claude
