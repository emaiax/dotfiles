#!/usr/bin/env bash
# Filesystem enforcement probes, wrapped by probe_script. Reads prove access via byte counts, not content, so nothing
# sensitive lands in a probe's context; write canaries self-clean.

set -euo pipefail

fs_cases() {
  cat <<'EOF'
fs-cred-read
fs-home-read
fs-allowread-code
fs-read-keychain-db
fs-write-claude-dir
fs-write-cred-touch
fs-write-keychain
fs-write-home-root
EOF
}

fs_run_case() {
  local case_id=$1 profile=$2
  case $case_id in
    fs-cred-read)
      probe_script "$profile" "$case_id" 'wc -c <"$HOME/.claude/.credentials.json"'
      ;;
    fs-home-read)
      probe_script "$profile" "$case_id" 'ls "$HOME/Documents"'
      ;;
    fs-allowread-code)
      probe_script "$profile" "$case_id" 'ls "$HOME/code" >/dev/null'
      ;;
    fs-read-keychain-db)
      probe_script "$profile" "$case_id" 'wc -c <"$HOME/Library/Keychains/login.keychain-db"'
      ;;
    fs-write-claude-dir)
      probe_script "$profile" "$case_id" 'touch "$HOME/.claude/profile-suite-canary"; rc=$?; rm -f "$HOME/.claude/profile-suite-canary"; exit $rc'
      ;;
    fs-write-cred-touch)
      # touch only bumps mtime on the existing file, so even the yolo run that succeeds does no harm.
      probe_script "$profile" "$case_id" 'touch "$HOME/.claude/.credentials.json"'
      ;;
    fs-write-keychain)
      # Branch reverted the keychain allowWrite; skip if the active base still grants it (stale config), the revert
      # itself is asserted statically (static-no-allowwrite-keychains).
      if [[ $profile != claude-yolo ]] && skip_if_base_drift "$case_id" "$profile" \
        ".sandbox.filesystem.allowWrite | index(\"$HOME/Library/Keychains\") != null" \
        "active base still grants the reverted Keychains allowWrite; re-run after just switch"; then
        return 0
      fi
      probe_script "$profile" "$case_id" 'touch "$HOME/Library/Keychains/profile-suite-canary"; rc=$?; rm -f "$HOME/Library/Keychains/profile-suite-canary"; exit $rc'
      ;;
    fs-write-home-root)
      probe_script "$profile" "$case_id" 'touch "$HOME/profile-suite-canary"; rc=$?; rm -f "$HOME/profile-suite-canary"; exit $rc'
      ;;
    *)
      echo "20-sandbox-fs: unknown case $case_id" >&2
      return 1
      ;;
  esac
}
