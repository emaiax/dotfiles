#!/usr/bin/env bash
# Copied from emaiax/dudumox:scripts/nix-locked.sh — keep in sync with the source.
set -uo pipefail

lockfile="/nix/.ci-lock"
timeout_s="300"

flock -w "$timeout_s" -E 99 "$lockfile" "$@"
rc=$?
if [ "$rc" -eq 99 ]; then
  echo "::error::timed out after ${timeout_s}s waiting for /nix store lock (another branch's nix-checks job is holding it)"
fi
exit "$rc"
