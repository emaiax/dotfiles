#!/usr/bin/env bash
# Result recording, assertions, and expected-table lookup shared by every suite.
# Everything funnels into results.jsonl; run.sh derives the summary and exit code from that file, so parallel probe processes need no shared counters.

set -euo pipefail

: "${TESTS_ROOT:?harness.sh needs TESTS_ROOT}"
: "${RESULTS_DIR:?harness.sh needs RESULTS_DIR}"

# Consumed by run.sh after sourcing.
# shellcheck disable=SC2034
PROFILES=(claude claudio claudio-thebot claude-yolo)

_color() {
  local code=$1
  shift
  if [[ -t 1 ]]; then printf '\033[%sm%s\033[0m' "$code" "$*"; else printf '%s' "$*"; fi
}

# t_record STATUS CASE_ID PROFILE [DETAIL] [OBSERVED] — the single sink for every outcome. OBSERVED carries the raw probe verdict so compare.md can show what actually happened, not just pass/fail.
t_record() {
  local status=$1 case_id=$2 profile=$3 detail=${4:-} observed=${5:-}
  mkdir -p "$RESULTS_DIR"
  jq -cn --arg c "$case_id" --arg p "$profile" --arg s "$status" --arg d "$detail" --arg o "$observed" \
    '{case: $c, profile: $p, status: $s, detail: $d, observed: $o}' >>"$RESULTS_DIR/results.jsonl"
  case $status in
    PASS) echo "$(_color 32 'ok    ') $profile/$case_id" ;;
    FAIL) echo "$(_color 31 'FAIL  ') $profile/$case_id — $detail" ;;
    XFAIL) echo "$(_color 33 'xfail ') $profile/$case_id — $detail" ;;
    SKIP) echo "$(_color 36 'skip  ') $profile/$case_id — $detail" ;;
    *)
      echo "harness: unknown status '$status'" >&2
      return 1
      ;;
  esac
}

# assert_jq CASE_ID PROFILE FILE JQ_EXPR EXPECTED — static assertion against a JSON artifact.
assert_jq() {
  local case_id=$1 profile=$2 file=$3 expr=$4 expected=$5
  local actual
  if ! actual=$(jq -r "$expr" "$file" 2>&1); then
    t_record FAIL "$case_id" "$profile" "jq error: $actual"
    return 0
  fi
  if [[ $actual == "$expected" ]]; then
    t_record PASS "$case_id" "$profile"
  else
    t_record FAIL "$case_id" "$profile" "expected '$expected', got '$actual' ($expr on ${file##*/})"
  fi
}

# assert_contains CASE_ID PROFILE HAYSTACK_FILE NEEDLE — plain-text presence check (wrapper scripts).
assert_contains() {
  local case_id=$1 profile=$2 file=$3 needle=$4
  if grep -qF -- "$needle" "$file"; then
    t_record PASS "$case_id" "$profile"
  else
    t_record FAIL "$case_id" "$profile" "'$needle' not found in ${file##*/}"
  fi
}

# expected_verdict PROFILE CASE_ID — first TSV column match; empty output means the table is incomplete, which run_case treats as FAIL.
expected_verdict() {
  awk -F'\t' -v c="$2" '$1 == c { print $2; exit }' "$TESTS_ROOT/expected/$1.tsv"
}

expected_note() {
  awk -F'\t' -v c="$2" '$1 == c { print $3; exit }' "$TESTS_ROOT/expected/$1.tsv"
}

# verdict_vs_expected CASE_ID PROFILE ACTUAL — maps a probe verdict against the expected table, honoring XFAIL_* markers.
verdict_vs_expected() {
  local case_id=$1 profile=$2 actual=$3
  local expected note
  expected=$(expected_verdict "$profile" "$case_id")
  note=$(expected_note "$profile" "$case_id")
  case $expected in
    "")
      t_record FAIL "$case_id" "$profile" "no entry in expected/$profile.tsv" "$actual"
      ;;
    "$actual")
      t_record PASS "$case_id" "$profile" "" "$actual"
      ;;
    XFAIL_"$actual")
      t_record XFAIL "$case_id" "$profile" "$note" "$actual"
      ;;
    SKIP)
      t_record SKIP "$case_id" "$profile" "$note" "$actual"
      ;;
    *)
      t_record FAIL "$case_id" "$profile" "expected $expected, observed $actual${note:+ ($note)}" "$actual"
      ;;
  esac
}

# skip_if_base_drift CASE_ID PROFILE JQ_TEST NOTE — dynamic probes run over the machine's active base settings, not the branch build (see lib/build.sh). If JQ_TEST detects drift that would invalidate this case, SKIP with NOTE and return 0 so the caller bails before spending a probe.
skip_if_base_drift() {
  local case_id=$1 profile=$2 jq_test=$3 note=$4
  if jq -e "$jq_test" "$HOME/.claude/settings.json" >/dev/null 2>&1; then
    t_record SKIP "$case_id" "$profile" "$note"
    return 0
  fi
  return 1
}

# with_timeout SECONDS CMD... — macOS ships no timeout(1); portable watchdog that reaps the child on expiry.
with_timeout() {
  local secs=$1
  shift
  "$@" &
  local pid=$!
  (
    local i
    for ((i = 0; i < secs; i++)); do
      sleep 1
      kill -0 "$pid" 2>/dev/null || exit 0
    done
    kill -TERM "$pid" 2>/dev/null || true
  ) &
  local watchdog=$!
  local rc=0
  wait "$pid" || rc=$?
  kill "$watchdog" 2>/dev/null || true
  wait "$watchdog" 2>/dev/null || true
  return "$rc"
}
