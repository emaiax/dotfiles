# Command gates, rendered into both agents' native syntax (see #121).
#
# Entries are command prefixes. They land in the user layer, and a higher-precedence layer cannot loosen them, so whatever goes here is the loosest any profile will ever be. Add sparingly.
#
# `git commit` is deliberately absent: local and reversible.
{
  ask = [
    "git push"

    # Destructive and hard to undo.
    "git reset --hard"
    "git checkout --"
    "git restore"
    "git clean"
    "git rebase"
    "rm -rf"
  ];

  # Irreversible, so these go to `permissions.deny` where nothing overrides them.
  denyHard = [
    "gh pr merge"
    "gh release"
    "fj pr merge"
    "fj release"
  ];

  # Reversible, so these become prose in claude-automode.nix's soft_deny, which claudio-thebot can carve an exception out of. OpenCode has no classifier and renders them as plain denies instead.
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

  # No allowlist: `ls` and `cat` are aliases resolving to nix store paths that no name-based rule matches, so an allowlist blocks them however it is written.

  # Derived globs that would widen the rule. `git checkout --` would become `git checkout --*`, swallowing `--track` and `--force`.
  opencodePatterns = {
    "git checkout --" = "git checkout -- *";
  };
}
