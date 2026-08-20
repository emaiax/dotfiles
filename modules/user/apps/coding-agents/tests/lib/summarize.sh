#!/usr/bin/env bash
# Digests results.jsonl into a terminal summary and results/<run>/compare.md (the observed-verdict grid, sandboxed × yolo). Exits nonzero if any FAIL exists, so run.sh's exit code is trustworthy for automation.

set -euo pipefail

TESTS_ROOT=${TESTS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
RESULTS_DIR=${RESULTS_DIR:-$TESTS_ROOT/results/latest}
R="$RESULTS_DIR/results.jsonl"

[[ -f $R ]] || {
  echo "summarize: no results at $R" >&2
  exit 2
}

count() { jq -rs "map(select(.status == \"$1\")) | length" "$R"; }

pass=$(count PASS)
fail=$(count FAIL)
xfail=$(count XFAIL)
skip=$(count SKIP)
echo "pass=$pass fail=$fail xfail=$xfail skip=$skip"

if [[ $fail -gt 0 ]]; then
  echo
  echo "failures:"
  jq -r 'select(.status == "FAIL") | "  \(.profile)/\(.case) — \(.detail)"' "$R"
fi

profiles=(claude claudio claudio-thebot claude-yolo)
{
  echo "# Profile suite run $(basename "$RESULTS_DIR")"
  echo
  echo "pass $pass / fail $fail / xfail $xfail / skip $skip — probe model: ${TESTS_MODEL:-haiku}"
  echo
  echo "## Observed verdicts (dynamic probes)"
  echo
  # Header and delimiter must carry the same cell count or GFM refuses to render the table. One leading "case" column plus one per profile; printf without a trailing separator so no phantom column appears.
  printf '| case |'
  printf ' %s |' "${profiles[@]}"
  printf '\n|---|'
  printf '---|%.0s' "${profiles[@]}"
  printf '\n'
  # Dynamic cases carry an observed verdict; static rows have none and are skipped here.
  while IFS= read -r case_id; do
    row="| $case_id |"
    for p in "${profiles[@]}"; do
      cell=$(jq -r --arg c "$case_id" --arg p "$p" \
        'select(.case == $c and .profile == $p and .observed != "") | "\(.observed) (\(.status))"' "$R" | tail -1)
      row+=" ${cell:-—} |"
    done
    echo "$row"
  done < <(jq -r 'select(.observed != "") | .case' "$R" | sort -u)
  echo
  echo "## Static failures, if any"
  echo
  jq -r 'select(.status == "FAIL" and .observed == "") | "- \(.profile)/\(.case) — \(.detail)"' "$R"
  echo
  echo "## Active-base drift"
  echo
  echo '```'
  cat "$RESULTS_DIR/base-drift.diff" 2>/dev/null || echo "not measured"
  echo '```'
} >"$RESULTS_DIR/compare.md"

echo
echo "compare.md: $RESULTS_DIR/compare.md"
[[ $fail -eq 0 ]]
