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
  assert_jq static-excluded-commands base "$base" '.sandbox.excludedCommands | sort | join(",")' 'docker *,fj *,gh *,rtk docker *,rtk fj *,rtk gh *'

  # Filesystem policy: the deny wall and the carve-outs the PR is about.
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

  assert_jq static-net-domains base "$base" '.sandbox.network.allowedDomains | sort | join(",")' '*.emx.casa,api.github.com,github.com'
  assert_jq static-net-nix-socket base "$base" '.sandbox.network.allowUnixSockets | join(",")' '/nix/var/nix/daemon-socket/socket'
  assert_jq static-net-trustd base "$base" '.sandbox.network.allowMachLookup | join(",")' 'com.apple.trustd.agent'
  assert_jq static-apple-events base "$base" '.sandbox.allowAppleEvents' 'true'

  # Permission gates: the deny list survives every mode including bypassPermissions, the ask list is what claude-yolo
  # trades away.
  assert_jq static-deny-gh-merge base "$base" '.permissions.deny | index("Bash(gh pr merge:*)") != null' 'true'
  assert_jq static-deny-gh-release base "$base" '.permissions.deny | index("Bash(gh release:*)") != null' 'true'
  assert_jq static-deny-fj-merge base "$base" '.permissions.deny | index("Bash(fj pr merge:*)") != null' 'true'
  assert_jq static-deny-fj-release base "$base" '.permissions.deny | index("Bash(fj release:*)") != null' 'true'
  # Read(//Users/...): // marks filesystem-root-absolute (permissions.nix).
  assert_jq static-deny-read-credentials base "$base" ".permissions.deny | index(\"Read(/$h/.claude/.credentials.json)\") != null" 'true'
  assert_jq static-deny-read-credentials-bak base "$base" ".permissions.deny | index(\"Read(/$h/.claude/.credentials.json.bak)\") != null" 'true'
  assert_jq static-deny-edit-credentials-bak base "$base" ".permissions.deny | index(\"Edit(/$h/.claude/.credentials.json.bak)\") != null" 'true'
  assert_jq static-ask-git-push base "$base" '.permissions.ask | index("Bash(git push:*)") != null' 'true'
  assert_jq static-ask-rm-rf base "$base" '.permissions.ask | index("Bash(rm -rf:*)") != null' 'true'
  assert_jq static-ask-git-reset base "$base" '.permissions.ask | index("Bash(git reset --hard:*)") != null' 'true'
  assert_jq static-default-mode-auto base "$base" '.permissions.defaultMode' 'auto'

  # rtk twins: found live by the gate probes; fix is permissions.nix's withRtkTwin.
  assert_jq static-ask-rtk-git-push base "$base" '.permissions.ask | index("Bash(rtk git push:*)") != null' 'true'
  assert_jq static-ask-rtk-checkout-exact base "$base" '.permissions.ask | index("Bash(rtk git checkout .)") != null' 'true'
  assert_jq static-ask-rtk-checkout-dashes base "$base" '.permissions.ask | index("Bash(rtk git checkout --:*)") != null' 'true'
  assert_jq static-deny-rtk-gh-merge base "$base" '.permissions.deny | index("Bash(rtk gh pr merge:*)") != null' 'true'
  assert_jq static-deny-rtk-fj-release base "$base" '.permissions.deny | index("Bash(rtk fj release:*)") != null' 'true'

  # claudio overlay: exactly the Obsidian socket grants and nothing else, canonical-JSON equality so any accidental
  # extra key fails loudly.
  local claudio_expected
  claudio_expected=$(jq -Sc . <<EOF
{"sandbox":{"filesystem":{"allowRead":["$h/.obsidian-cli.sock"]},"network":{"allowUnixSockets":["$h/.obsidian-cli.sock"]}}}
EOF
  )
  if [[ $(jq -Sc . "${OVERLAY[claudio]}") == "$claudio_expected" ]]; then
    t_record PASS static-overlay-shape claudio
  else
    t_record FAIL static-overlay-shape claudio "overlay diverged from the two expected socket grants: $(jq -Sc . "${OVERLAY[claudio]}")"
  fi

  # claude-yolo overlay: exactly {sandbox:{enabled:false}}. Anything more means the profile grew scope nobody reviewed.
  if [[ $(jq -Sc . "${OVERLAY[claude-yolo]}") == '{"sandbox":{"enabled":false}}' ]]; then
    t_record PASS static-overlay-shape claude-yolo
  else
    t_record FAIL static-overlay-shape claude-yolo "overlay is $(jq -Sc . "${OVERLAY[claude-yolo]}")"
  fi

  # thebot overlay shape is asserted in 50-automode.sh (it is purely an autoMode override).

  # Wrapper flags: the behavior-defining arguments each wrapper must carry.
  assert_contains static-wrapper-skip-permissions claude-yolo "$(readlink -f "${WRAPPER[claude-yolo]}")" '--dangerously-skip-permissions'
  assert_contains static-wrapper-adddir-context claudio-thebot "$(readlink -f "${WRAPPER[claudio-thebot]}")" "$h/code/claudio"
  assert_contains static-wrapper-adddir-publish claudio-thebot "$(readlink -f "${WRAPPER[claudio-thebot]}")" "$h/code/claudio-thebot/claudio-core"
}
