#!/usr/bin/env bash
# Resolves the branch's built artifacts: profile wrappers, their overlay settings JSONs, and the base settings.json. Everything comes from nix build of the flake in this worktree, never from the activated system, so the suite tests the PR's code. The one exception is documented in README.md: probe sessions inherit the machine's active base settings, and this file measures that drift.

set -euo pipefail

: "${TESTS_ROOT:?build.sh needs TESTS_ROOT}"
: "${RESULTS_DIR:?build.sh needs RESULTS_DIR}"

REPO_ROOT=$(cd "$TESTS_ROOT/../../../.." && pwd)

# resolve_artifacts — populates BASE_SETTINGS, WRAPPER[<profile>], OVERLAY[<profile>]. Cached per run in paths.env since nix eval takes ~10s even warm.
declare -A WRAPPER OVERLAY
BASE_SETTINGS=

resolve_artifacts() {
  local cache="$RESULTS_DIR/paths.env"
  if [[ ! -f $cache ]]; then
    local host
    host=$(hostname -s)
    local attr=".#darwinConfigurations.${host}.config.home-manager.users.${USER}.home.activationPackage"
    local gen
    gen=$(cd "$REPO_ROOT" && nix build --no-link --print-out-paths "$attr" 2>/dev/null)
    [[ -n $gen ]] || {
      echo "build.sh: nix build of $attr produced nothing" >&2
      return 1
    }
    # ~/.claude/settings.json is deployed as an out-of-store symlink to a writable state path (so rtk can patch it at runtime), which means following the home-files symlink lands on the machine's ACTIVE, mutated copy. The pristine branch artifact is the store JSON the activation script installs into that state path; pull it from the activate script instead.
    local base
    base=$(grep -o '/nix/store/[a-z0-9]*-claude-code-settings\.json' "$gen/activate" | head -1)
    [[ -f $base ]] || {
      echo "build.sh: could not locate claude-code-settings.json in $gen/activate" >&2
      return 1
    }
    {
      echo "GEN=$gen"
      echo "HM_BIN=$gen/home-path/bin"
      echo "BASE_SETTINGS=$base"
    } >"$cache"
  fi
  # shellcheck disable=SC1090
  source "$cache"

  local p
  for p in claude claudio claudio-thebot claude-yolo; do
    WRAPPER[$p]="$HM_BIN/$p"
    [[ -x ${WRAPPER[$p]} ]] || {
      echo "build.sh: missing wrapper ${WRAPPER[$p]}" >&2
      return 1
    }
  done

  # The default profile has no overlay; the others carry theirs as a --settings store path baked into the wrapper script.
  OVERLAY[claude]=""
  for p in claudio claudio-thebot claude-yolo; do
    OVERLAY[$p]=$(grep -o -- '--settings /nix/store/[^ ]*' "$(readlink -f "${WRAPPER[$p]}")" | awk '{print $2}')
    [[ -f ${OVERLAY[$p]} ]] || {
      echo "build.sh: could not extract overlay for $p" >&2
      return 1
    }
  done
}

# drift_report — diff of branch base settings vs the machine's active one; informational, written into the results dir for compare.md.
drift_report() {
  local active="$HOME/.claude/settings.json"
  local out="$RESULTS_DIR/base-drift.diff"
  if [[ ! -f $active ]]; then
    echo "active base settings not found at $active" >"$out"
    return 0
  fi
  if diff <(jq -S . "$BASE_SETTINGS") <(jq -S . "$active") >"$out" 2>&1; then
    echo "none" >"$out"
  fi
}
