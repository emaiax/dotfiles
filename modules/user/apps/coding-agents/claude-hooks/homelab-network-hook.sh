#!/usr/bin/env bash
set -euo pipefail

# Wildcards the homelab domain into the sandbox's network allowlist, so any homelab service is reachable without a per-service patch. SessionStart, not PreToolUse: stable for the session's lifetime, no reason to redo this on every Bash call. Idempotent, best-effort.

[[ -n "${HOMELAB_DOMAIN:-}" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

settings="$HOME/.claude/settings.json"
[[ -f "$settings" ]] || exit 0
real_settings="$(readlink -f "$settings" 2>/dev/null || echo "$settings")"

pattern="*.${HOMELAB_DOMAIN}"

jq -e --arg h "$pattern" '(.sandbox.network.allowedDomains // []) | index($h) != null' \
  "$real_settings" >/dev/null 2>&1 && exit 0

tmp="$(mktemp)"
jq --arg h "$pattern" \
  '.sandbox.network.allowedDomains = ((.sandbox.network.allowedDomains // []) + [$h] | unique)' \
  "$real_settings" >"$tmp" && mv "$tmp" "$real_settings"
