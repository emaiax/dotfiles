# Development

This doc covers general dev workflow. Read it before touching code, git, or a PR in any repo, not just when it feels non-trivial.

## Workflow

- The repo's own conventions win over every default below. Read its recent history (commits, branches, PRs) before assuming one of these applies.
- macOS locally (nix-darwin + home-manager, flakes), NixOS on homelab. Do not mix their tooling.
- Worktree + branch before any change. Non-trivial work in phases with a gate between them. Group changes in logical commits, test-driven, one PR per logical concern.
- Branch names, default when the repo has no clear convention: `type-kebab-case-description`, same types as commit messages, issue number prepended when relevant (`fix-133-probe-script-notrun`), never suffixed.
- Push requires approval, except a branch with an already-open PR: keep pushing to it without re-asking each time.
- Every PR goes through `/code-review` and gets explicit approval before merge, no exceptions.
- Ephemeral tools via `nix shell nixpkgs#<tool>`. Project commands inside `nix develop` when available. Dotfiles via home-manager, never by hand.

## Reading CI and CLI gotchas

- @docs/ci.md
- @docs/fj-cli.md
- @docs/gh-cli.md
