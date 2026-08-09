#!/usr/bin/env bash
# Set the terminal tab title from the repo + branch Claude Code is working in.
#
# Runs as a Claude Code hook. Two things make this less trivial than `printf`:
#
#   1. The hook's stdout is captured by Claude Code, not written to the terminal —
#      and on UserPromptSubmit stdout is injected into the model's context, so this
#      script must print nothing at all.
#   2. The hook process has no controlling terminal: /dev/tty answers "device not
#      configured". The pty has to be found by walking up the process tree to the
#      `claude` process, which does have one.
#
# Prints nothing, never fails the hook.
set -u

find_tty() {
  local p="$1" t ppid
  for _ in 1 2 3 4 5 6 7 8; do
    [ -z "$p" ] && return 1
    t="$(ps -o tty= -p "$p" 2>/dev/null | tr -d ' ')"
    case "$t" in
      '' | '??') ppid="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')" ;;
      *)
        printf '%s' "$t"
        return 0
        ;;
    esac
    [ "$ppid" = "$p" ] && return 1
    p="$ppid"
  done
  return 1
}

tty_dev="$(find_tty "$PPID")" || exit 0
[ -w "/dev/$tty_dev" ] || exit 0

# --git-common-dir, not --show-toplevel: inside a worktree the toplevel is the
# worktree directory, so the title would read the branch name twice.
common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
if [ -n "$common_dir" ]; then
  repo="$(basename "$(dirname "$common_dir")")"
else
  repo="$(basename "$PWD")"
fi
branch="$(git branch --show-current 2>/dev/null)"

# Branches here are <issue>-<category>-<slug>; surface the issue number, which is
# what identifies the work, and drop the category, which never does.
case "$branch" in
  [0-9]*-*-*)
    issue="${branch%%-*}"
    rest="${branch#*-}"
    title="$repo #$issue ${rest#*-}"
    ;;
  '') title="$repo" ;;
  *) title="$repo $branch" ;;
esac

printf '\033]0;%s\007' "$title" > "/dev/$tty_dev" 2>/dev/null || true
exit 0
