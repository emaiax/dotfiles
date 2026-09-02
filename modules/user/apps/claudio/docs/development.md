# Development

This doc covers general dev workflow, reading CI, and fj CLI gotchas. Read it before touching code, git, or a PR in any repo, not just when it feels non-trivial.

## Workflow

- macOS locally (nix-darwin + home-manager, flakes), NixOS on homelab. Do not mix their tooling.
- Worktree + branch before any change. Non-trivial work in phases with a gate between them. Group changes in logical commits, test-driven, one PR per logical concern.
- Branch names: the repo's own convention wins when its history shows one clearly. Default otherwise: `type-kebab-case-description`, same types as commit messages, issue number prepended when relevant (`fix-133-probe-script-notrun`), never suffixed.
- Push requires approval, except a branch with an already-open PR: keep pushing to it without re-asking each time.
- Every PR goes through `/code-review` and gets explicit approval before merge, no exceptions.
- Ephemeral tools via `nix shell nixpkgs#<tool>`. Project commands inside `nix develop` when available. Dotfiles via home-manager, never by hand.

## Reading CI

Read before proposing any fix for a red CI run.

### Get the real log

- Never diagnose from the job name, the summary line, or a screenshot. Fetch the raw log or the project's equivalent
- Find the first failing step, not the last. Later failures are usually fallout
- Locate the first error line in that step. Everything after it is noise until proven otherwise

### Classify before fixing

Sort the failure into exactly one bucket and say which:

1. Regression: the code under test is wrong. Fix the code
2. Test is wrong: the test encodes an assumption the change intentionally broke. Fix the test, and say why the assumption changed
3. Formatter or linter: whitespace, import order, style. Run the project formatter locally, commit the result alone
4. Rebase noise: the branch is behind and the failure is from someone else's change. Rebase first, then re-run before touching anything
5. Infra: runner, network, cache, flaky dependency. Re-run once. If it fails the same way twice, it is not infra

A formatter failure and a regression in the same run are two commits, never one.

### Before proposing a fix

- Reproduce locally inside `nix develop` when the project has one. If it cannot be reproduced locally, say so
- State the bucket, the first error line, and the proposed change in three sentences before writing code
- Do not re-run CI as a substitute for reading it

## fj CLI gotchas

`fj` (forgejo-cli) rejects flags its help text doesn't warn you about defaulting to. Read this before any `fj` command in any repo, not just the one where you last used it.

- `fj pr create [TITLE]`: title is a bare positional argument, not `--title`. Body: `--body <TEXT>` for something short, `--body-file <PATH>` for anything multi-line or with markdown. `-A`/`--autofill` skips both, filling title and body from the branch's commits: a single commit's message becomes the PR verbatim, several commits use the branch name as title and list every commit message in the body.
- `fj pr view <ID>`: ID is positional, no `--repo` flag. Run it from inside the repo's checkout (or a worktree of it). Add a subcommand to see one part instead of the whole PR: `diff`, `files`, `commits`, `comments`, `labels`.
- `fj pr edit <ID> body [NEW_BODY]`: also positional, no `--body-file`. Fine for short text, pass it inline.
- `fj pr comment <ID> [BODY]`: also positional, but unlike `pr edit body` this one does take `--body-file <PATH>`, use it for anything multi-line.
- `fj pr review <ID> list`: read-only. `fj` can only list existing reviews, it has no command to submit an approve, request-changes, or line comment. Do that from the web UI, `fj pr browse <ID>` opens it.
- `fj pr merge <ID>`: ID positional. It does not delete the source branch by default, pass `-d`/`--delete` for that. `-M`/`--method` picks the merge style (`merge`, `rebase`, `rebase-merge`, `squash`, `manual`).
- `fj issue create --template <name>`: matches the template's `name:` field, not its filename. Run `fj issue templates` first to get the exact name. Without `--body-file` it opens an interactive editor and hangs in a non-interactive session.
- `fj actions tasks`: paginated, 20 tasks per page. Pass `-p <N>`/`--page <N>` if the job you're chasing isn't on the first page.
