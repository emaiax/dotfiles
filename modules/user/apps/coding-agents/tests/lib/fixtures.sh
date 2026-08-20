#!/usr/bin/env bash
# Throwaway git fixtures for destructive probe payloads. Every fixture is a fresh repo with a local bare "remote", so a yolo probe that really executes git push has somewhere harmless to land. Branch name is trunk on purpose: nothing in this suite ever touches a branch called main, not even a disposable one.

set -euo pipefail

# mk_fixture NAME — prints the fixture dir. Layout: <dir>/repo (worktree, cwd for the probe) and <dir>/remote.git (bare). The repo is left with: one commit ahead of the remote (push has something to do), a junkdir (rm -rf target), and a dirty tracked file (reset/checkout target).
mk_fixture() {
  local name=$1
  local dir
  dir=$(mktemp -d "${TMPDIR:-/tmp}/claude-suite-${name}.XXXXXX")

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

fixture_tree_clean() {
  [[ -z $(git -C "$1/repo" status --porcelain) ]]
}
