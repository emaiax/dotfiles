# fj CLI gotchas

Flag and argument quirks for `fj` (forgejo-cli) that its own `--help` text doesn't warn you about. Read this before any `fj` command in any repo, not just the one where you last used it.

- If the repo defines issue or PR templates, use them, never write a free-form body instead.
  - Issues: run `fj issue templates` to list them.
  - PRs: `fj pr create` has no `--template` flag at all, find the file yourself and pass it via `--body-file`. Forgejo checks `.forgejo/`, `.gitea/`, `.github/`, then `docs/`, in that order, for both issue and PR templates ([source](https://forgejo.org/docs/latest/user/issue-pull-request-templates/)).
- Get real help with `fj help <noun> <verb>`, not `<noun> <verb> --help`. Verified this session: `fj pr merge --help` is blocked outright by the permission layer, the `help` subcommand form sidesteps it.

`fj` rejects flags its help text doesn't warn you about defaulting to.

- `fj pr create [TITLE]`
  - Title is positional, not `--title`.
  - Body: `--body <TEXT>` for something short, `--body-file <PATH>` for anything multi-line or with markdown.
  - `-A`/`--autofill` skips both: a single commit's message becomes the PR verbatim, several commits use the branch name as title and list every commit message in the body.
- `fj pr view <ID>`
  - ID is positional, no `--repo` flag. Run it from inside the repo's checkout (or a worktree of it).
  - Add a subcommand to see one part instead of the whole PR: `diff`, `files`, `commits`, `comments`, `labels`.
- `fj pr edit <ID> body [NEW_BODY]`: also positional, no `--body-file`. Fine for short text, pass it inline.
- `fj pr comment <ID> [BODY]`: also positional, but unlike `pr edit body` this one takes `--body-file <PATH>`, use it for anything multi-line.
- `fj pr review <ID> list`
  - Read-only: `fj` can only list existing reviews, it has no command to submit an approve, request-changes, or line comment.
  - Do that from the web UI, `fj pr browse <ID>` opens it.
- `fj pr merge <ID>`
  - ID positional. Does not delete the source branch by default, pass `-d`/`--delete` for that.
  - `-M`/`--method` picks the merge style (`merge`, `rebase`, `rebase-merge`, `squash`, `manual`).
- `fj issue create --template <name>`
  - Matches the template's `name:` field, not its filename. Run `fj issue templates` first to get the exact name.
  - Without `--body-file` it opens an interactive editor and hangs in a non-interactive session.
- `fj actions tasks`: paginated, 20 tasks per page. Pass `-p <N>`/`--page <N>` if the job you're chasing isn't on the first page.
