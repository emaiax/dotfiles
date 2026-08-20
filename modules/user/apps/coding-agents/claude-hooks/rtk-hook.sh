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

# Add the forgejo host to the sandbox's network allowlist so `git push`/`fj`
# can reach it. It's private, so it never becomes a settings.json literal in
# the Nix store — sops decrypts it asynchronously via a launchd agent on
# macOS (modules/user/git/default.nix), so patching settings.json during
# home-manager activation would race it. Reading $FJ_FALLBACK_HOST here,
# well after activation, is race-free. Idempotent, best-effort.
patch_forgejo_allowlist() {
  [[ -n "${FJ_FALLBACK_HOST:-}" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  local settings="$HOME/.claude/settings.json"
  [[ -f "$settings" ]] || return 0
  local real_settings
  real_settings="$(readlink -f "$settings" 2>/dev/null || echo "$settings")"

  # allowedDomains matches on hostname, not host:port or user@host — strip the scheme, any
  # path, any userinfo, and any :port so a FJ_FALLBACK_HOST like https://forgejo:3000/ still
  # yields a bare `forgejo` that can actually match. Keeping the port would append an entry
  # that never matches, and the idempotence check below would then treat that bogus entry as
  # done and never repair it.
  local host="${FJ_FALLBACK_HOST#*://}"
  host="${host%%/*}"
  host="${host##*@}"
  host="${host%%:*}"

  jq -e --arg h "$host" '(.sandbox.network.allowedDomains // []) | index($h) != null' \
    "$real_settings" >/dev/null 2>&1 && return 0

  local tmp
  tmp="$(mktemp)"
  jq --arg h "$host" \
    '.sandbox.network.allowedDomains = ((.sandbox.network.allowedDomains // []) + [$h] | unique)' \
    "$real_settings" >"$tmp" && mv "$tmp" "$real_settings"
}
patch_forgejo_allowlist || true

exec rtk hook claude
