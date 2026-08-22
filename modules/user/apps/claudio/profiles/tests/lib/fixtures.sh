#!/usr/bin/env bash
# Throwaway git fixtures for destructive probe payloads: a fresh repo with a local bare "remote" so a probe that really executes git push has somewhere harmless to land. Branch is trunk on purpose — nothing here ever touches a branch called main, not even a disposable one.

set -euo pipefail

# Under ~/code, not /tmp: the sandbox's allowWrite covers that tree, so a gated command that reaches execution can actually succeed against its bare remote instead of failing on EPERM before the permission gate is even measured.
FIXTURE_ROOT=${FIXTURE_ROOT:-$HOME/code/.claude-profile-suite}

# mk_fixture NAME — prints the fixture dir: <dir>/repo (worktree, probe cwd) and <dir>/remote.git (bare). Left with a commit ahead of remote (push target), a junkdir (rm -rf target), and a dirty tracked file (reset/checkout target).
mk_fixture() {
  local name=$1
  local dir
  mkdir -p "$FIXTURE_ROOT"
  dir=$(mktemp -d "$FIXTURE_ROOT/${name}.XXXXXX")

  git init -q -b trunk "$dir/repo"
  git -C "$dir/repo" config user.email suite@localhost
  git -C "$dir/repo" config user.name "profile-test-suite"
  git -C "$dir/repo" config commit.gpgsign false

  echo "fixture seed" >"$dir/repo/tracked.txt"
  git -C "$dir/repo" add tracked.txt
  git -C "$dir/repo" commit -qm "seed"

  git init -q --bare "$dir/remote.git"
  git -C "$dir/repo" remote add origin "$dir/remote.git"
  git -C "$dir/repo" push -q origin trunk

  echo "second commit" >>"$dir/repo/tracked.txt"
  git -C "$dir/repo" commit -qam "ahead of remote"

  mkdir "$dir/repo/junkdir"
  echo "junk" >"$dir/repo/junkdir/file.txt"

  echo "dirty working tree" >>"$dir/repo/tracked.txt"

  echo "$dir"
}

# Side-effect predicates: each answers "did the gated command actually execute?" from fixture state alone.

fixture_pushed() {
  local dir=$1
  [[ $(git -C "$dir/remote.git" rev-parse trunk 2>/dev/null) == $(git -C "$dir/repo" rev-parse trunk) ]]
}

fixture_junk_removed() {
  [[ ! -e "$1/repo/junkdir" ]]
}

# git diff, never porcelain: reset/checkout only revert tracked changes, and porcelain always reports the untracked junkdir regardless, which would make a successful revert look dirty.
fixture_tracked_reverted() {
  git -C "$1/repo" diff --quiet
}
