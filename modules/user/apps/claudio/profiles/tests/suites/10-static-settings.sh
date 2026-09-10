#!/usr/bin/env bash
# Static assertions over the branch's generated artifacts: base settings.json, each profile's overlay + wrapper flags.
# Free, and catches config regressions before any probe spends a token.

set -euo pipefail

static_settings_run() {
  local base=$BASE_SETTINGS
  local h=$HOME

  # Sandbox hardening: all three toggles that make the boundary real rather than advisory.
  assert_jq static-sandbox-enabled base "$base" '.sandbox.enabled' 'true'
  assert_jq static-sandbox-fail-unavailable base "$base" '.sandbox.failIfUnavailable' 'true'
  assert_jq static-sandbox-no-unsandboxed-retry base "$base" '.sandbox.allowUnsandboxedCommands' 'false'
  assert_jq static-sandbox-autoallow-bash base "$base" '.sandbox.autoAllowBashIfSandboxed' 'true'

  # Must stay globs (bare names fail open) and keep the rtk twins (permissions.nix).
  assert_jq static-excluded-commands base "$base" '.sandbox.excludedCommands | sort | join(",")' 'docker *,fj *,gh *,rtk docker *,rtk fj *,rtk gh *,rtk ssh *,ssh *'

  # Filesystem policy: the deny wall and the carve-outs the PR is about.
  # allowWrite is a no-op upstream (docs/sandbox-notes.md), so filesystem isolation is off; network sandbox stays on.
  assert_jq static-filesystem-disabled base "$base" '.sandbox.filesystem.disabled' 'true'
  assert_jq static-denyread-home base "$base" ".sandbox.filesystem.denyRead | index(\"$h\") != null" 'true'
  assert_jq static-denyread-credentials base "$base" ".sandbox.filesystem.denyRead | index(\"$h/.claude/.credentials.json\") != null" 'true'
  assert_jq static-allowread-keychains base "$base" ".sandbox.filesystem.allowRead | index(\"$h/Library/Keychains\") != null" 'true'
  assert_jq static-allowread-claude-dir base "$base" ".sandbox.filesystem.allowRead | index(\"$h/.claude\") != null" 'true'
  assert_jq static-allowread-rtk-dir base "$base" ".sandbox.filesystem.allowRead | index(\"$h/Library/Application Support/rtk\") != null" 'true'
  assert_jq static-allowwrite-claude-dir base "$base" ".sandbox.filesystem.allowWrite | index(\"$h/.claude\") != null" 'true'
  assert_jq static-allowwrite-rtk-dir base "$base" ".sandbox.filesystem.allowWrite | index(\"$h/Library/Application Support/rtk\") != null" 'true'
  # Tried and reverted (docs/sandbox-notes.md, error 100001), guard against it coming back.
  assert_jq static-no-allowwrite-keychains base "$base" ".sandbox.filesystem.allowWrite | index(\"$h/Library/Keychains\") == null" 'true'
  assert_jq static-denywrite-credentials base "$base" ".sandbox.filesystem.denyWrite | index(\"$h/.claude/.credentials.json\") != null" 'true'

  assert_jq static-net-domains base "$base" '.sandbox.network.allowedDomains | sort | join(",")' '*.emx.casa,*.local,api.github.com,app.asana.com,github.com,registry.yarnpkg.com'
  assert_jq static-net-sockets base "$base" '.sandbox.network.allowUnixSockets | sort | join(",")' "$h/.docker/run/docker.sock,/nix/var/nix/daemon-socket/socket"
  assert_jq static-net-trustd base "$base" '.sandbox.network.allowMachLookup | join(",")' 'com.apple.trustd.agent'
  assert_jq static-apple-events base "$base" '.sandbox.allowAppleEvents' 'true'

  # Permission gates: deny survives every mode including bypassPermissions, ask is what a yolo-style profile
  # trades away. These live on the claudio overlay only (permissions.nix's mkClaudeCodePermissions), not the
  # shared base (2026-09-10): claude-code/default.nix carries none of this, so a bare `claude` invocation isn't
  # gated by it, and claudio-thebot is yolo-only now (zero permissions of its own too, asserted below).
  assert_jq static-deny-gh-merge claudio "${OVERLAY[claudio]}" '.permissions.deny | index("Bash(gh pr merge:*)") != null' 'true'
  assert_jq static-deny-gh-release claudio "${OVERLAY[claudio]}" '.permissions.deny | index("Bash(gh release:*)") != null' 'true'
  assert_jq static-deny-fj-merge claudio "${OVERLAY[claudio]}" '.permissions.deny | index("Bash(fj pr merge:*)") != null' 'true'
  assert_jq static-deny-fj-release claudio "${OVERLAY[claudio]}" '.permissions.deny | index("Bash(fj release:*)") != null' 'true'
  # Read(//Users/...): // marks filesystem-root-absolute (permissions.nix).
  assert_jq static-deny-read-credentials claudio "${OVERLAY[claudio]}" ".permissions.deny | index(\"Read(/$h/.claude/.credentials.json)\") != null" 'true'
  assert_jq static-deny-read-credentials-bak claudio "${OVERLAY[claudio]}" ".permissions.deny | index(\"Read(/$h/.claude/.credentials.json.bak)\") != null" 'true'
  assert_jq static-deny-edit-credentials-bak claudio "${OVERLAY[claudio]}" ".permissions.deny | index(\"Edit(/$h/.claude/.credentials.json.bak)\") != null" 'true'
  assert_jq static-ask-git-push claudio "${OVERLAY[claudio]}" '.permissions.ask | index("Bash(git push:*)") != null' 'true'
  assert_jq static-ask-rm-rf claudio "${OVERLAY[claudio]}" '.permissions.ask | index("Bash(rm -rf:*)") != null' 'true'
  assert_jq static-ask-git-reset claudio "${OVERLAY[claudio]}" '.permissions.ask | index("Bash(git reset --hard:*)") != null' 'true'
  assert_jq static-default-mode-auto claudio "${OVERLAY[claudio]}" '.permissions.defaultMode' 'auto'

  # rtk twins: found live by the gate probes; fix is permissions.nix's withRtkTwin.
  assert_jq static-ask-rtk-git-push claudio "${OVERLAY[claudio]}" '.permissions.ask | index("Bash(rtk git push:*)") != null' 'true'
  assert_jq static-ask-rtk-checkout-exact claudio "${OVERLAY[claudio]}" '.permissions.ask | index("Bash(rtk git checkout .)") != null' 'true'
  assert_jq static-ask-rtk-checkout-dashes claudio "${OVERLAY[claudio]}" '.permissions.ask | index("Bash(rtk git checkout --:*)") != null' 'true'
  assert_jq static-deny-rtk-gh-merge claudio "${OVERLAY[claudio]}" '.permissions.deny | index("Bash(rtk gh pr merge:*)") != null' 'true'
  assert_jq static-deny-rtk-fj-release claudio "${OVERLAY[claudio]}" '.permissions.deny | index("Bash(rtk fj release:*)") != null' 'true'

  # base settings.json: zero permissions definition on purpose (2026-09-10) — a bare `claude` invocation isn't
  # gated by anything meant for the specialized profiles. Guard against it silently coming back.
  assert_jq static-base-no-permissions base "$base" 'has("permissions")' 'false'

  # claudio overlay: sandbox opt-out plus the full permissions bundle asserted individually above, nothing
  # else. Key-set check only, not a full literal diff: array order inside ask/deny/allow isn't semantically
  # meaningful and would make this brittle against an unrelated reorder in permissions.nix.
  assert_jq static-claudio-overlay-keys claudio "${OVERLAY[claudio]}" '. | keys | sort | join(",")' 'permissions,sandbox'
  assert_jq static-claudio-sandbox-shape claudio "${OVERLAY[claudio]}" '.sandbox | keys | sort | join(",")' 'enabled,filesystem,network'
  assert_jq static-claudio-sandbox-enabled-false claudio "${OVERLAY[claudio]}" '.sandbox.enabled' 'false'
  assert_jq static-claudio-obsidian-read claudio "${OVERLAY[claudio]}" '.sandbox.filesystem.allowRead | join(",")' "$h/.obsidian-cli.sock"
  assert_jq static-claudio-obsidian-socket claudio "${OVERLAY[claudio]}" '.sandbox.network.allowUnixSockets | join(",")' "$h/.obsidian-cli.sock"

  # claude-yolo overlay (2026-09-10: the base defines no permissions at all now, so this profile opts back into
  # just the credential-file deny explicitly instead of losing it as a side effect): exactly
  # {permissions:{deny:[...credential rules...]},sandbox:{enabled:false}}. Anything more means the profile grew
  # scope nobody reviewed; checked as key-set + individual rules rather than a full literal diff (deny array
  # order isn't semantically meaningful).
  assert_jq static-claudeyolo-overlay-keys claude-yolo "${OVERLAY[claude-yolo]}" '. | keys | sort | join(",")' 'permissions,sandbox'
  assert_jq static-claudeyolo-permissions-keys claude-yolo "${OVERLAY[claude-yolo]}" '.permissions | keys | join(",")' 'deny'
  assert_jq static-claudeyolo-sandbox-shape claude-yolo "${OVERLAY[claude-yolo]}" '.sandbox | keys | join(",")' 'enabled'
  assert_jq static-claudeyolo-sandbox-enabled-false claude-yolo "${OVERLAY[claude-yolo]}" '.sandbox.enabled' 'false'
  assert_jq static-claudeyolo-deny-read-credentials claude-yolo "${OVERLAY[claude-yolo]}" ".permissions.deny | index(\"Read(/$h/.claude/.credentials.json)\") != null" 'true'
  assert_jq static-claudeyolo-deny-read-credentials-bak claude-yolo "${OVERLAY[claude-yolo]}" ".permissions.deny | index(\"Read(/$h/.claude/.credentials.json.bak)\") != null" 'true'
  assert_jq static-claudeyolo-deny-edit-credentials-bak claude-yolo "${OVERLAY[claude-yolo]}" ".permissions.deny | index(\"Edit(/$h/.claude/.credentials.json.bak)\") != null" 'true'
  # And nothing more: no ask, no allow, no hardDeny tier rides along with the credential-only opt-in.
  assert_jq static-claudeyolo-no-ask claude-yolo "${OVERLAY[claude-yolo]}" '.permissions | has("ask")' 'false'
  assert_jq static-claudeyolo-no-allow claude-yolo "${OVERLAY[claude-yolo]}" '.permissions | has("allow")' 'false'

  # claudio-thebot overlay (2026-09-10 consolidation: this profile is yolo-only now, the gated "auto" variant
  # and the separate claudio-thebot-yolo binary are both gone): {permissions:{},sandbox:{enabled:false}}, the
  # same zero-permissions posture as the base, asserted explicitly here rather than left implicit.
  if [[ $(jq -Sc . "${OVERLAY[claudio-thebot]}") == '{"permissions":{},"sandbox":{"enabled":false}}' ]]; then
    t_record PASS static-overlay-shape claudio-thebot
  else
    t_record FAIL static-overlay-shape claudio-thebot "overlay is $(jq -Sc . "${OVERLAY[claudio-thebot]}")"
  fi

  # Wrapper flags: the behavior-defining arguments each wrapper must carry.
  assert_contains static-wrapper-skip-permissions claude-yolo "$(readlink -f "${WRAPPER[claude-yolo]}")" '--dangerously-skip-permissions'
  assert_contains static-wrapper-adddir-context claudio-thebot "$(readlink -f "${WRAPPER[claudio-thebot]}")" "$h/code/claudio"
  assert_contains static-wrapper-adddir-publish claudio-thebot "$(readlink -f "${WRAPPER[claudio-thebot]}")" "$h/code/claudio-thebot/claudio-core"
  assert_contains static-wrapper-skip-permissions claudio-thebot "$(readlink -f "${WRAPPER[claudio-thebot]}")" '--dangerously-skip-permissions'
}
