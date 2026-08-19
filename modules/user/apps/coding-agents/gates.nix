# The single source of truth for command gates, rendered into both agents' native syntax (see issue #121).
#
# These rules used to exist only in opencode.nix. Claude Code had none, and agent-jail launched it with `--permission-mode auto` on top of that — so "never commit, push, or post anything external until I approve" was enforced in one agent and prose-only in the other. Switching agents silently changed security posture. This file removes that asymmetry.
#
# Shaped after Claude's `permissions` block: `ask` and `deny` hold command prefixes, so anything starting with the string matches.
#
# ONE-WAY: these land in the user layer, and a higher-precedence layer cannot loosen them. An `allow` passed via `--settings` does NOT override an `ask` or `deny` from below — verified directly, both stayed blocked. So every entry here binds `claude`, `claudio` and `claudio-thebot` alike, and a profile can only ever add restrictions. Think twice before adding: whatever goes here is the *loosest* any profile will ever be.
#
# What is deliberately NOT here: `git commit`. Committing is local and reversible, so it stays ungated; what matters is what leaves the machine.
{
  ask = [
    # The moment work leaves the machine. Local commits are free; this is the gate that matters.
    "git push"

    # Destructive and hard to undo — worth a beat before running.
    "git reset --hard"
    "git checkout --"
    "git restore"
    "git clean"
    "git rebase"
    "rm -rf"
  ];

  # Irreversible publication: merging and releasing cannot be walked back, so these stay command patterns in `permissions.deny`, which nothing overrides.
  denyHard = [
    "gh pr merge"
    "gh release"
    "fj pr merge"
    "fj release"
  ];

  # Reversible publication — a PR or comment can be closed or deleted. Both agents deny these, but by different means, because only one of them has a classifier:
  #
  # - OpenCode renders them as command denies, same as denyHard.
  # - Claude expresses them as prose in claude-automode.nix's `soft_deny`, so a profile can carve out an exception. claudio-thebot exists to publish and needs exactly that, and `permissions.deny` offers no way to grant it.
  #
  # The trade is real: a soft deny also clears when you state the intent directly in conversation. That matches "publishing is mine to authorise", but it is weaker than the hard list above, which is why merge and release are not in here.
  denySoft = [
    "gh pr create"
    "gh pr ready"
    "gh pr review"
    "gh pr comment"
    "gh pr close"
    "gh issue create"
    "gh issue edit"
    "gh issue comment"

    "fj pr create"
    "fj pr review"
    "fj pr close"
    "fj pr comment"
    "fj issue create"
    "fj issue edit"
    "fj issue comment"
  ];

  # Matched literally rather than as a prefix.
  askExact = [ "git checkout ." ];

  # No allowlist here on purpose. `default` mode plus an allowlist would fence better than a blocklist, but it is unusable in this environment: `ls`, `cat` and friends are shell aliases that resolve to absolute nix store paths, and no name-based rule matches those — allowing `ls`, `lsd` and `bat` together still left every one of them blocked. The paths also change on every update. So the profiles stay in `auto` and containment comes from the denies above.

  # OpenCode globs where the derived `<cmd>*` would widen the rule. Deriving `git checkout --` gives `git checkout --*`, which also swallows `--track` and `--force`; only the pathspec form is meant.
  opencodePatterns = {
    "git checkout --" = "git checkout -- *";
  };
}
