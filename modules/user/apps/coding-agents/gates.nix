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
# prefixes, so anything starting with the string matches.
#
# ONE-WAY: these land in the user layer, and a higher-precedence layer cannot
# loosen them. An `allow` passed via `--settings` does NOT override an `ask` or
# `deny` from below — verified directly, both stayed blocked. So every entry
# here binds `claude`, `claudio` and `claudio-thebot` alike, and a profile can
# only ever add restrictions. Think twice before adding: whatever goes here is
# the *loosest* any profile will ever be.
#
# What is deliberately NOT here: `git commit`. Committing is local and
# reversible, so it stays ungated; what matters is what leaves the machine.
{
  ask = [
    # The moment work leaves the machine. Local commits are free; this is the
    # gate that matters.
    "git push"

    # Destructive and hard to undo — worth a beat before running.
    "git reset --hard"
    "git checkout --"
    "git restore"
    "git clean"
    "git rebase"
    "rm -rf"
  ];

  # Published presence is the operator's, not the agent's: anything that puts a
  # visible artefact under their name on a forge is denied outright rather than
  # asked, because approving it in the moment is exactly how it slips.
  deny = [
    "gh pr create"
    "gh pr ready"
    "gh pr merge"
    "gh pr review"
    "gh pr comment"
    "gh pr close"
    "gh issue create"
    "gh issue edit"
    "gh issue comment"
    "gh release"

    # This repo's Forgejo equivalents of the gh gates above.
    "fj pr create"
    "fj pr merge"
    "fj pr review"
    "fj pr close"
    "fj pr comment"
    "fj issue create"
    "fj issue edit"
    "fj issue comment"
    "fj release"
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
