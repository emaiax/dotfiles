#!/usr/bin/env bash
# Auto-mode layering per profile, validated at the config level: entries are prose judged by a model at runtime, not
# mechanical rules, so asserting the shipped config is the deterministic limit here. Behavioral probes would need an
# unprompted external action: flaky and unsafe.

set -euo pipefail

automode_run() {
  local base=$BASE_SETTINGS

  # Base layer (claude-automode.nix): $defaults must lead both lists so the built-in rules survive the custom additions.
  assert_jq automode-env-count base "$base" '.autoMode.environment | length' '5'
  assert_jq automode-env-defaults-first base "$base" '.autoMode.environment[0]' '$defaults'
  assert_jq automode-env-org base "$base" '.autoMode.environment | map(select(contains("personal single-developer"))) | length' '1'
  assert_jq automode-env-registry base "$base" '.autoMode.environment | map(select(contains("Nix is the package manager"))) | length' '1'
  assert_jq automode-env-visibility base "$base" '.autoMode.environment | map(select(contains("assume a repository is public"))) | length' '1'
  assert_jq automode-env-workstation base "$base" '.autoMode.environment | map(select(contains("personal workstation"))) | length' '1'

  assert_jq automode-softdeny-count base "$base" '.autoMode.soft_deny | length' '2'
  assert_jq automode-softdeny-defaults-first base "$base" '.autoMode.soft_deny[0]' '$defaults'
  assert_jq automode-softdeny-forge-presence base "$base" '.autoMode.soft_deny[1] | contains("theirs to initiate")' 'true'
  # The forge-presence rule must stay phrased as a category, not an absolute, so a future profile can carve
  # itself an exception the same way claudio-thebot's now-removed autoMode.allow used to (see claude-automode.nix).
  assert_jq automode-softdeny-overridable base "$base" '.autoMode.soft_deny[1] | contains("under any circumstances") | not' 'true'

  # The base must not ship an allow layer: loosening is a per-profile decision.
  assert_jq automode-base-no-allow base "$base" '.autoMode | has("allow")' 'false'

  # claudio: inherits auto-mode untouched. Its overlay carrying any autoMode key would be unreviewed scope creep.
  assert_jq automode-overlay-absent claudio "${OVERLAY[claudio]}" 'has("autoMode")' 'false'

  # claude-yolo: bypassPermissions skips auto mode entirely, and the overlay must not pretend otherwise.
  assert_jq automode-overlay-absent claude-yolo "${OVERLAY[claude-yolo]}" 'has("autoMode")' 'false'

  # claudio-thebot (2026-09-10 consolidation: this profile is yolo-only now, the gated "auto" variant and its
  # bot-identity autoMode.allow carve-out are both gone): same bypassPermissions reasoning as claude-yolo — auto
  # mode is never consulted under --dangerously-skip-permissions, so there is nothing left to carve an
  # exception out of.
  assert_jq automode-overlay-absent claudio-thebot "${OVERLAY[claudio-thebot]}" 'has("autoMode")' 'false'
}
