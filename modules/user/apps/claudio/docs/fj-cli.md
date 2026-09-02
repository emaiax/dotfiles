# fj CLI gotchas

`fj` (forgejo-cli) rejects flags its help text doesn't warn you about defaulting to. Read this before any `fj` command in any repo, not just the one where you last used it.

- `fj pr create [TITLE]`: title is a bare positional argument, not `--title`. Body: `--body <TEXT>` for something short, `--body-file <PATH>` for anything multi-line or with markdown. `-A`/`--autofill` skips both, filling title and body from the branch's commits: a single commit's message becomes the PR verbatim, several commits use the branch name as title and list every commit message in the body.
- `fj pr view <ID>`: ID is positional, no `--repo` flag. Run it from inside the repo's checkout (or a worktree of it). Add a subcommand to see one part instead of the whole PR: `diff`, `files`, `commits`, `comments`, `labels`.
- `fj pr edit <ID> body [NEW_BODY]`: also positional, no `--body-file`. Fine for short text, pass it inline.
- `fj pr comment <ID> [BODY]`: also positional, but unlike `pr edit body` this one does take `--body-file <PATH>`, use it for anything multi-line.
- `fj pr review <ID> list`: read-only. `fj` can only list existing reviews, it has no command to submit an approve, request-changes, or line comment. Do that from the web UI, `fj pr browse <ID>` opens it.
- `fj pr merge <ID>`: ID positional. It does not delete the source branch by default, pass `-d`/`--delete` for that. `-M`/`--method` picks the merge style (`merge`, `rebase`, `rebase-merge`, `squash`, `manual`).
- `fj issue create --template <name>`: matches the template's `name:` field, not its filename. Run `fj issue templates` first to get the exact name. Without `--body-file` it opens an interactive editor and hangs in a non-interactive session.
- `fj actions tasks`: paginated, 20 tasks per page. Pass `-p <N>`/`--page <N>` if the job you're chasing isn't on the first page.
