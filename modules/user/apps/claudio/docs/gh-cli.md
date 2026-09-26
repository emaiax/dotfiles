# gh CLI gotchas

Flag and argument quirks for `gh` (GitHub CLI) that its own `--help` text doesn't warn you about. Read this before any `gh` command in any repo, not just the one where you last used it.

- If the repo defines issue or PR templates, use them, never write a free-form body instead. `gh` has no listing command for either, read `.github/ISSUE_TEMPLATE/` and `.github/PULL_REQUEST_TEMPLATE.md` directly, `gh` only ever looks in `.github/`.
- Get real help with `gh help <noun> <verb>`, not `<noun> <verb> --help`. Verified this session: `gh pr comment --help`, and bare `gh pr --help`/`gh issue --help`, get intercepted by the `rtk` wrapper: it shows its own generic help, or attempts the real action, instead of gh's help. The `help` subcommand form sidesteps it. `gh pr merge --help` is also blocked outright by the permission layer.

`gh` takes title and body as flags, the opposite of `fj`'s positional arguments (see `fj-cli.md`).

- `gh pr create`
  - `-t`/`--title` and `-b`/`--body` are flags, not positional (`fj` is the reverse).
  - `-f`/`--fill` autofills from commits, like `fj`'s `-A`/`--autofill`.
  - `-T`/`--template <file>` picks a specific PR template file when the repo has more than one.
  - Without `--title`/`--body`/`--fill` it prompts interactively, unverified whether that hangs or errors in a non-interactive session here, don't rely on it.
- `gh issue create`
  - Same flag-based pattern. `-T`/`--template <name>` matches the template's `name:` field, same convention as `fj`.
  - `gh` has no `fj issue templates`-equivalent listing command.
- `gh pr merge`
  - Needs an explicit strategy flag, `-m`/`--merge`, `-r`/`--rebase`, or `-s`/`--squash`, no default.
  - `-d`/`--delete-branch` deletes the branch after merge, same idea as `fj`'s `-d`/`--delete`.
- `gh pr review`: unlike `fj pr review`, this one submits a real review: `--approve`, `--comment`, `--request-changes`, each paired with `-b`/`--body` or `-F`/`--body-file`.
