# The single source of truth for command gates, rendered into both agents'
# native syntax (see issue #121).
#
# These rules used to exist only in opencode.nix. Claude Code had none, and
# agent-jail launched it with `--permission-mode auto` on top of that — so
# "never commit, push, or post anything external until I approve" was enforced
# in one agent and prose-only in the other. Switching agents silently changed
# security posture. This file removes that asymmetry.
#
# Shaped after Claude's `permissions` block: `ask` and `deny` hold command
# prefixes, so anything starting with the string matches. The two escape
# hatches below exist only because a couple of rules can't be derived from a
# prefix without widening them.
#
# Note that under the sandbox these gates are mostly *legibility* rather than
# security for anything network-shaped — a denied `git push` fails at the
# network boundary anyway, but as a gate it fails with a clear reason instead
# of a timeout. Don't grow this list to chase security; the network and
# filesystem boundaries are the real controls.
{
  ask = [
    "git commit"

    # Destructive and hard to undo — worth a beat before running.
    "git reset --hard"
    "git checkout --"
    "git restore"
    "git clean"
    "git rebase"
    "rm -rf"
  ];

  deny = [
    "git push"

    "gh pr create"
    "gh pr ready"
    "gh pr merge"
    "gh pr review"

    # This repo's Forgejo equivalents of the gh gates above.
    "fj pr create"
    "fj pr merge"
    "fj pr review"
    "fj pr close"
    "fj pr comment"
  ];

  # Matched literally rather than as a prefix.
  askExact = [ "git checkout ." ];

  # OpenCode globs where the derived `<cmd>*` would widen the rule. Deriving
  # `git checkout --` gives `git checkout --*`, which also swallows `--track`
  # and `--force`; only the pathspec form is meant.
  opencodePatterns = {
    "git checkout --" = "git checkout -- *";
  };
}
