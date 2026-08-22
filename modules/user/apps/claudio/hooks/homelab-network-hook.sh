#!/usr/bin/env bash
set -euo pipefail

[[ -n "${HOMELAB_DOMAIN:-}" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v sponge >/dev/null 2>&1 || exit 0

settings="$HOME/.claude/settings.json"

# Check if the settings file exists
[[ -f "$settings" ]] || exit 0

# Resolve the real path of the settings file, handling symlinks
real_settings="$(readlink -f "$settings" 2>/dev/null || echo "$settings")"

# Update the allowedDomains in the settings file
jq --arg h "*.${HOMELAB_DOMAIN}" \
  '.sandbox.network.allowedDomains |= ((. // []) + [$h] | unique)' \
  "$real_settings" | sponge "$real_settings"
