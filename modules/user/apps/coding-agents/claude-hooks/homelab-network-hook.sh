#!/usr/bin/env bash
set -euo pipefail

# Patches the sandbox's network allowlist with a wildcard for the homelab domain, so `git push`/`fj`
# and anything else on the LAN can reach it. Wildcarded rather than one exact host per service (the
# old approach, scoped to forgejo alone) so every homelab service under the same domain is covered
# without a new patch each time one comes up. HOMELAB_DOMAIN is exported at zsh startup from a sops
# secret (modules/user/sops/default.nix) — private, so it never becomes a settings.json literal in
# the Nix store. SessionStart, not PreToolUse: the result is stable for the session's lifetime, so
# there's no reason to redo the readlink+jq work on every Bash call. Idempotent, best-effort.

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
