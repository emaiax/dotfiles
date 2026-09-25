#!/usr/bin/env bash
# Tests for multi-backend CLI resolution and Antigravity hook safety policies.

set -euo pipefail

cli_backends_run() {
  local p
  for p in claudio claude-yolo claudio-thebot; do
    assert_contains static-wrapper-backend-flag "$p" "${WRAPPER[$p]}" '--backend|-b)'
    assert_contains static-wrapper-agy-sugar "$p" "${WRAPPER[$p]}" '--agy)'
    assert_contains static-wrapper-claude-sugar "$p" "${WRAPPER[$p]}" '--claude|--claude-code)'
    assert_contains static-wrapper-opencode-sugar "$p" "${WRAPPER[$p]}" '--opencode)'
    assert_contains static-wrapper-env-override "$p" "${WRAPPER[$p]}" 'CLAUDIO_BACKEND'
  done

  assert_contains static-wrapper-exec-agy claudio "${WRAPPER[claudio]}" 'exec agy "$@"'
  assert_contains static-wrapper-yolo-agy claude-yolo "${WRAPPER[claude-yolo]}" 'exec env CLAUDIO_DANGEROUSLY_SKIP_PERMISSIONS=1 agy --dangerously-skip-permissions "$@"'
  assert_contains static-wrapper-thebot-agy claudio-thebot "${WRAPPER[claudio-thebot]}" 'exec env CLAUDIO_THEBOT_SESSION=1 CLAUDIO_DANGEROUSLY_SKIP_PERMISSIONS=1 agy'

  # Behavioral CLI parsing tests
  local out
  if out=$("${WRAPPER[claudio]}" --backend invalid 2>&1); then
    t_record FAIL static-cli-invalid-backend claudio "expected failure, got success: $out"
  elif [[ "$out" == *"unknown backend 'invalid'"* ]]; then
    t_record PASS static-cli-invalid-backend claudio
  else
    t_record FAIL static-cli-invalid-backend claudio "unexpected output: $out"
  fi

  if out=$(CLAUDIO_BACKEND=claude-code "${WRAPPER[claudio]}" --backend invalid 2>&1); then
    t_record FAIL static-cli-flag-overrides-env claudio "expected failure, got success: $out"
  elif [[ "$out" == *"unknown backend 'invalid'"* ]]; then
    t_record PASS static-cli-flag-overrides-env claudio
  else
    t_record FAIL static-cli-flag-overrides-env claudio "unexpected output: $out"
  fi

  if out=$("${WRAPPER[claudio]}" -b 2>&1); then
    t_record FAIL static-cli-missing-arg claudio "expected failure, got success: $out"
  elif [[ "$out" == *"missing argument for -b"* ]]; then
    t_record PASS static-cli-missing-arg claudio
  else
    t_record FAIL static-cli-missing-arg claudio "unexpected output: $out"
  fi

  # Hook behavior tests
  local hook_bin="$TESTS_ROOT/../../hooks/antigravity-hook.sh"
  local hooks_json
  hooks_json=$(find -L "$GEN" -name "hooks.json" 2>/dev/null | head -1 || true)
  if [[ -z "$hooks_json" || ! -f "$hooks_json" ]]; then
    hooks_json=$(ls -d /nix/store/*antigravity-hooks.json 2>/dev/null | tail -1 || true)
  fi

  local policy_file=""
  if [[ -n "$hooks_json" && -f "$hooks_json" ]]; then
    policy_file=$(grep -o '/nix/store/[a-z0-9]*-claudio-policy\.json' "$hooks_json" | head -1 || true)
  fi

  if [[ -f "$hook_bin" && -f "$policy_file" ]]; then
    local res
    # 1. Ask gate: git push
    res=$(echo '{"toolCall":{"name":"run_command","args":{"CommandLine":"git push origin main"}}}' | bash "$hook_bin" "$policy_file")
    if [[ $(echo "$res" | jq -r '.decision') == "ask" ]]; then
      t_record PASS hook-ask-git-push agy
    else
      t_record FAIL hook-ask-git-push agy "expected ask, got: $res"
    fi

    # 2. Hard deny: gh pr merge
    res=$(echo '{"toolCall":{"name":"run_command","args":{"CommandLine":"gh pr merge 123"}}}' | bash "$hook_bin" "$policy_file")
    if [[ $(echo "$res" | jq -r '.decision') == "deny" ]]; then
      t_record PASS hook-deny-gh-merge agy
    else
      t_record FAIL hook-deny-gh-merge agy "expected deny, got: $res"
    fi

    # 3. Credential path in file tool: ~/.ssh
    res=$(echo "{\"toolCall\":{\"name\":\"view_file\",\"args\":{\"AbsolutePath\":\"${HOME}/.ssh/id_ed25519\"}}}" | bash "$hook_bin" "$policy_file")
    if [[ $(echo "$res" | jq -r '.decision') == "deny" ]]; then
      t_record PASS hook-deny-view-ssh agy
    else
      t_record FAIL hook-deny-view-ssh agy "expected deny, got: $res"
    fi

    # 4. Credential path in command: cat ~/.ssh
    res=$(echo "{\"toolCall\":{\"name\":\"run_command\",\"args\":{\"CommandLine\":\"cat ${HOME}/.ssh/id_ed25519\"}}}" | bash "$hook_bin" "$policy_file")
    if [[ $(echo "$res" | jq -r '.decision') == "deny" ]]; then
      t_record PASS hook-deny-cmd-ssh agy
    else
      t_record FAIL hook-deny-cmd-ssh agy "expected deny, got: $res"
    fi

    # 5. Normal command rewrite: git log -> rtk git log
    res=$(echo '{"toolCall":{"name":"run_command","args":{"CommandLine":"git log -n 5"}}}' | bash "$hook_bin" "$policy_file")
    if [[ $(echo "$res" | jq -r '.decision') == "allow" && $(echo "$res" | jq -r '.overwrite.CommandLine') == "rtk git log -n 5" ]]; then
      t_record PASS hook-rtk-rewrite-git-log agy
    else
      t_record FAIL hook-rtk-rewrite-git-log agy "expected rewrite to rtk git log, got: $res"
    fi
  else
    t_record SKIP hook-policy-tests agy "policy_file or hook_bin not found"
  fi

  # 6. Antigravity settings store generation & schema
  local agy_settings_json
  agy_settings_json=$(grep -o '/nix/store/[a-z0-9]*-antigravity-cli-settings\.json' "$GEN/activate" 2>/dev/null | head -1 || true)
  if [[ -z "$agy_settings_json" || ! -f "$agy_settings_json" ]]; then
    agy_settings_json=$(ls -d /nix/store/*antigravity-cli-settings.json 2>/dev/null | tail -1 || true)
  fi

  if [[ -f "$agy_settings_json" ]]; then
    local cs telemetry verbosity has_git
    cs=$(jq -r '.colorScheme // empty' "$agy_settings_json")
    telemetry=$(jq -r '.enableTelemetry' "$agy_settings_json")
    verbosity=$(jq -r '.verbosity // empty' "$agy_settings_json")
    has_git=$(jq -r '.permissions.allow[] | select(. == "command(git *)")' "$agy_settings_json" 2>/dev/null || true)

    if [[ "$cs" == "tokyo night" && "$telemetry" == "false" && "$verbosity" == "low" && "$has_git" == "command(git *)" ]]; then
      t_record PASS settings-store-schema agy
    else
      t_record FAIL settings-store-schema agy "unexpected settings content: $(cat "$agy_settings_json")"
    fi
  else
    t_record FAIL settings-store-schema agy "could not find antigravity-cli-settings.json"
  fi

  # 7. Activation script includes smart merge
  if grep -q 'antigravityCliSettings' "$GEN/activate" 2>/dev/null && grep -q 'trustedWorkspaces' "$GEN/activate" 2>/dev/null; then
    t_record PASS activation-has-smart-merge agy
  else
    t_record FAIL activation-has-smart-merge agy "activation script missing antigravityCliSettings or trustedWorkspaces merge"
  fi

  # 8. Behavioral test of smart-merge logic
  if [[ -f "$agy_settings_json" ]]; then
    local test_live test_merged
    test_live='{"colorScheme":"old","enableTelemetry":true,"trustedWorkspaces":["/test/worktree"],"permissions":{"allow":["command(adhoc-tool)"]}}'
    test_merged=$(echo "$test_live" | jq -s --slurpfile nix "$agy_settings_json" '
      .[0] as $live | $nix[0] as $nix |
      ($live * $nix) * {
        trustedWorkspaces: ($live.trustedWorkspaces // []),
        permissions: {
          allow: ((($live.permissions.allow // []) + ($nix.permissions.allow // [])) | unique)
        }
      }
    ')
    local merged_ws merged_adhoc merged_git merged_cs
    merged_ws=$(echo "$test_merged" | jq -r '.trustedWorkspaces[0] // empty')
    merged_adhoc=$(echo "$test_merged" | jq -r '.permissions.allow[] | select(. == "command(adhoc-tool)")' 2>/dev/null || true)
    merged_git=$(echo "$test_merged" | jq -r '.permissions.allow[] | select(. == "command(git *)")' 2>/dev/null || true)
    merged_cs=$(echo "$test_merged" | jq -r '.colorScheme')

    if [[ "$merged_ws" == "/test/worktree" && "$merged_adhoc" == "command(adhoc-tool)" && "$merged_git" == "command(git *)" && "$merged_cs" == "tokyo night" ]]; then
      t_record PASS smart-merge-preserves-and-unions agy
    else
      t_record FAIL smart-merge-preserves-and-unions agy "merge failed: $test_merged"
    fi
  else
    t_record SKIP smart-merge-preserves-and-unions agy "agy_settings_json missing"
  fi

  # 9. Tracked seed in claudio/antigravity matches generated store settings
  local seed_claudio="$TESTS_ROOT/../../antigravity/settings.json"
  if [[ -f "$seed_claudio" && -f "$agy_settings_json" ]]; then
    if cmp -s "$seed_claudio" "$agy_settings_json"; then
      t_record PASS tracked-seed-matches-store agy
    else
      t_record FAIL tracked-seed-matches-store agy "seed differs from store json: $(diff -u "$seed_claudio" "$agy_settings_json" || true)"
    fi
  else
    t_record FAIL tracked-seed-matches-store agy "seed file missing: $seed_claudio or $agy_settings_json"
  fi
}
