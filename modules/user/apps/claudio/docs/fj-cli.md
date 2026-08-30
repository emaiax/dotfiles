# fj CLI gotchas

`fj` (forgejo-cli) rejects flags its help text doesn't warn you about defaulting to. Read this before any `fj` command in any repo, not just the one where you last used it.

- `fj pr create [TITLE]`: title is a bare positional argument, not `--title`. Body: `--body <TEXT>` for something short, `--body-file <PATH>` for anything multi-line or with markdown.
- `fj pr view <ID>`: ID is positional, no `--repo` flag. Run it from inside the repo's checkout (or a worktree of it).
- `fj pr edit <ID> body [NEW_BODY]`: also positional, no `--body-file`. Fine for short text, pass it inline.
- `fj issue create --template <name>`: matches the template's `name:` field, not its filename. Without `--body-file` it opens an interactive editor and hangs in a non-interactive session.
