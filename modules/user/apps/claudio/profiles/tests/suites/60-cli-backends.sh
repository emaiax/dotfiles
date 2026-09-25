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
    res=$(echo '{"toolCall":{"name":"view_file","args":{"AbsolutePath":"/Users/emaiax/.ssh/id_ed25519"}}}' | bash "$hook_bin" "$policy_file")
    if [[ $(echo "$res" | jq -r '.decision') == "deny" ]]; then
      t_record PASS hook-deny-view-ssh agy
    else
      t_record FAIL hook-deny-view-ssh agy "expected deny, got: $res"
    fi

    # 4. Credential path in command: cat ~/.ssh
    res=$(echo '{"toolCall":{"name":"run_command","args":{"CommandLine":"cat /Users/emaiax/.ssh/id_ed25519"}}}' | bash "$hook_bin" "$policy_file")
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
}
