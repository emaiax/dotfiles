# The single source of truth for command gates, rendered into both agents'
# native syntax (see issue #121).
#
# These rules used to exist only in opencode.nix. Claude Code had none, and
# agent-jail launched it with `--permission-mode auto` on top of that — so
# "never commit, push, or post anything external until I approve" was enforced
# in one agent and prose-only in the other. Switching agents silently changed
# security posture. This file removes that asymmetry.
#
# `cmd` is the command prefix. `exact = true` means match only that literal
# invocation; otherwise anything starting with `cmd` matches. `opencodePattern`
# overrides the derived glob where OpenCode's syntax needs a shape the generic
# derivation would widen — see `git checkout --` below.
#
# Note that under the sandbox these gates are mostly *legibility* rather than
# security for anything network-shaped — a denied `git push` fails at the
# network boundary anyway, but as a gate it fails with a clear reason instead of
# a timeout. Don't grow the pattern list to chase security; the network and
# filesystem boundaries are the real controls.
[
  # Anything that publishes, or that I have to approve per my own rules.
  {
    cmd = "git commit";
    action = "ask";
  }
  {
    cmd = "git push";
    action = "deny";
  }

  {
    cmd = "gh pr create";
    action = "deny";
  }
  {
    cmd = "gh pr ready";
    action = "deny";
  }
  {
    cmd = "gh pr merge";
    action = "deny";
  }
  {
    cmd = "gh pr review";
    action = "deny";
  }

  # This repo's Forgejo equivalents of the gh gates above.
  {
    cmd = "fj pr create";
    action = "deny";
  }
  {
    cmd = "fj pr merge";
    action = "deny";
  }
  {
    cmd = "fj pr review";
    action = "deny";
  }
  {
    cmd = "fj pr close";
    action = "deny";
  }
  {
    cmd = "fj pr comment";
    action = "deny";
  }

  # Destructive and hard to undo — worth a beat before running.
  {
    cmd = "git reset --hard";
    action = "ask";
  }
  {
    cmd = "git checkout --";
    action = "ask";
    # Deriving this would give `git checkout --*`, which also swallows
    # `--track`, `--force` and friends. Only the pathspec form is meant here.
    opencodePattern = "git checkout -- *";
  }
  {
    cmd = "git checkout .";
    action = "ask";
    exact = true;
  }
  {
    cmd = "git restore";
    action = "ask";
  }
  {
    cmd = "git clean";
    action = "ask";
  }
  {
    cmd = "git rebase";
    action = "ask";
  }
  {
    cmd = "rm -rf";
    action = "ask";
  }
]
