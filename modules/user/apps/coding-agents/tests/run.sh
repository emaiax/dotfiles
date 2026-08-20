#!/usr/bin/env bash
# Orchestrator for the profile test suite. Static assertions run serially and free; dynamic probes fan out as (case, profile) jobs, each a subshell spawning one headless claude session, throttled by --jobs. All outcomes land in results.jsonl; the summary, compare.md, and the exit code derive from that file alone.

set -euo pipefail

TESTS_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export TESTS_ROOT

JOBS=5
STATIC_ONLY=0
CASE_FILTER='*'
PROFILE_FILTER=()

usage() {
  cat <<'EOF'
usage: run.sh [--static-only] [--profile NAME]... [--case GLOB] [--jobs N]
  --static-only   config assertions only; spawns no claude sessions
  --profile NAME  restrict dynamic probes to one or more profiles
  --case GLOB     restrict dynamic probes to matching case ids (e.g. 'gate-*')
  --jobs N        probe parallelism (default 5)
env: TESTS_MODEL (probe session model, default haiku), PROBE_TIMEOUT (seconds, default 300)
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --static-only) STATIC_ONLY=1 ;;
    --profile)
      PROFILE_FILTER+=("$2")
      shift
      ;;
    --case)
      CASE_FILTER=$2
      shift
      ;;
    --jobs)
      JOBS=$2
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

for dep in jq git nix awk curl; do
  command -v "$dep" >/dev/null || {
    echo "run.sh: missing dependency: $dep" >&2
    exit 2
  }
done
((BASH_VERSINFO[0] >= 5)) || {
  echo "run.sh: bash >= 5 required (found $BASH_VERSION); the home-manager env provides one" >&2
  exit 2
}

RUN_ID=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="$TESTS_ROOT/results/$RUN_ID"
export RESULTS_DIR
mkdir -p "$RESULTS_DIR"
ln -sfn "$RUN_ID" "$TESTS_ROOT/results/latest"

# shellcheck source=lib/harness.sh
source "$TESTS_ROOT/lib/harness.sh"
# shellcheck source=lib/build.sh
source "$TESTS_ROOT/lib/build.sh"

echo "== resolving branch artifacts (nix build)"
resolve_artifacts
drift_report
if [[ $(cat "$RESULTS_DIR/base-drift.diff") != none ]]; then
  echo "!! active base settings drift from the branch build (see results/$RUN_ID/base-drift.diff); dynamic probes run over the active base"
fi

echo "== static: settings"
# shellcheck source=suites/10-static-settings.sh
source "$TESTS_ROOT/suites/10-static-settings.sh"
static_settings_run

echo "== static: auto-mode"
# shellcheck source=suites/50-automode.sh
source "$TESTS_ROOT/suites/50-automode.sh"
automode_run

if [[ $STATIC_ONLY == 0 ]]; then
  [[ ${#PROFILE_FILTER[@]} -gt 0 ]] || PROFILE_FILTER=("${PROFILES[@]}")

  # Manifest of (suite, case, profile) jobs, honoring the filters.
  manifest="$RESULTS_DIR/manifest.tsv"
  : >"$manifest"
  for suite in 20-sandbox-fs 30-sandbox-net 40-permission-gates; do
    # shellcheck source=/dev/null
    source "$TESTS_ROOT/suites/$suite.sh"
  done
  for profile in "${PROFILE_FILTER[@]}"; do
    while IFS= read -r case_id; do
      # shellcheck disable=SC2254
      case $case_id in
        $CASE_FILTER) printf '%s\t%s\t%s\n' fs_run_case "$case_id" "$profile" >>"$manifest" ;;
      esac
    done < <(fs_cases)
    while IFS= read -r case_id; do
      # shellcheck disable=SC2254
      case $case_id in
        $CASE_FILTER) printf '%s\t%s\t%s\n' net_run_case "$case_id" "$profile" >>"$manifest" ;;
      esac
    done < <(net_cases)
    while IFS= read -r case_id; do
      # shellcheck disable=SC2254
      case $case_id in
        $CASE_FILTER) printf '%s\t%s\t%s\n' gate_run_case "$case_id" "$profile" >>"$manifest" ;;
      esac
    done < <(gate_cases)
  done

  total=$(wc -l <"$manifest" | tr -d ' ')
  echo "== dynamic: $total probes on model '${TESTS_MODEL:-haiku}', $JOBS at a time"

  # shellcheck source=lib/fixtures.sh
  source "$TESTS_ROOT/lib/fixtures.sh"
  # shellcheck source=lib/probe.sh
  source "$TESTS_ROOT/lib/probe.sh"
  # Fixture repos are per-run throwaways; reclaim the whole root when the run ends, however it ends.
  trap 'rm -rf "$FIXTURE_ROOT"' EXIT
  # Build each profile's merged --settings once, serially, before forking probe jobs.
  prebuild_probe_settings "${PROFILE_FILTER[@]}"

  # Each job is a forked subshell: it inherits the sourced functions and resolved arrays, runs one probe, and appends one line to results.jsonl.
  while IFS=$'\t' read -r fn case_id profile; do
    while (($(jobs -rp | wc -l) >= JOBS)); do
      wait -n || true
    done
    "$fn" "$case_id" "$profile" &
  done <"$manifest"
  wait
fi

echo
echo "== summary"
"$TESTS_ROOT/lib/summarize.sh"
