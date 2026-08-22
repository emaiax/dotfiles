#!/usr/bin/env bash
# Auto-mode layering per profile, validated at the config level — entries are prose judged by a model at runtime, not mechanical rules, so asserting the shipped config is the deterministic limit here. Behavioral probes would need an unprompted external action: flaky and unsafe.

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
  # The forge-presence rule must stay phrased as a category, not an absolute: claudio-thebot's allow needs to be able to override it (see claude-automode.nix).
  assert_jq automode-softdeny-overridable base "$base" '.autoMode.soft_deny[1] | contains("under any circumstances") | not' 'true'

  # The base must not ship an allow layer: loosening is a per-profile decision, and today only thebot makes it.
  assert_jq automode-base-no-allow base "$base" '.autoMode | has("allow")' 'false'

  # claudio: inherits auto-mode untouched. Its overlay carrying any autoMode key would be unreviewed scope creep.
  assert_jq automode-overlay-absent claudio "${OVERLAY[claudio]}" 'has("autoMode")' 'false'

  # claude-yolo: bypassPermissions skips auto mode entirely, and the overlay must not pretend otherwise.
  assert_jq automode-overlay-absent claude-yolo "${OVERLAY[claude-yolo]}" 'has("autoMode")' 'false'

  # claudio-thebot: exactly one loosening — the bot-identity carve-out for its publish repo — layered as an allow that keeps $defaults first and scopes itself to that one repository.
  assert_jq automode-thebot-allow-count claudio-thebot "${OVERLAY[claudio-thebot]}" '.autoMode.allow | length' '2'
  assert_jq automode-thebot-allow-defaults-first claudio-thebot "${OVERLAY[claudio-thebot]}" '.autoMode.allow[0]' '$defaults'
  assert_jq automode-thebot-allow-bot-identity claudio-thebot "${OVERLAY[claudio-thebot]}" '.autoMode.allow[1] | contains("its own bot identity")' 'true'
  assert_jq automode-thebot-allow-scoped claudio-thebot "${OVERLAY[claudio-thebot]}" '.autoMode.allow[1] | contains("still applies everywhere else")' 'true'
  assert_jq automode-thebot-allow-names-repo claudio-thebot "${OVERLAY[claudio-thebot]}" ".autoMode.allow[1] | contains(\"$HOME/code/claudio-thebot/claudio-core\")" 'true'
  # And nothing else: no soft_deny or environment overrides may ride along in the overlay.
  assert_jq automode-thebot-no-softdeny claudio-thebot "${OVERLAY[claudio-thebot]}" '.autoMode | has("soft_deny")' 'false'
  assert_jq automode-thebot-no-env claudio-thebot "${OVERLAY[claudio-thebot]}" '.autoMode | has("environment")' 'false'
  assert_jq automode-thebot-only-automode claudio-thebot "${OVERLAY[claudio-thebot]}" 'keys | join(",")' 'autoMode'
}
