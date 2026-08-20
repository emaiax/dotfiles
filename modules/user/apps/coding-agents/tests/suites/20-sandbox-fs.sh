#!/usr/bin/env bash
# Filesystem enforcement probes. Every payload is wrapped by probe_script (sandbox semantics apply to children), reads prove access via byte counts rather than content so nothing sensitive lands in a probe session's context, and write canaries clean up after themselves in the same script so a yolo run leaves no residue.

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
