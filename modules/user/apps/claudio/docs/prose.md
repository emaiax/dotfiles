# Prose formatting

Applies to any prose that ends up rendered by markdown or git: commit message bodies, PR and issue descriptions, review comments, doc paragraphs, multi-sentence comments in config files.

## Never hard-wrap

One raw line per paragraph, no column width. The renderer wraps it.

Structural line breaks are fine and expected:

- markdown headers
- list items, one item per line
- table rows
- code, YAML, JSON blocks
- blockquote lines

Judge by the artifact the text ends up in, not by the file that produces it:

- A heredoc, string literal, or template that builds a commit body, PR body, or doc produces prose. Its output is the artifact, so it must not be wrapped, even though it lives inside a script
- A comment in source code is part of the code, not a prose artifact. Comments wrap at 120 columns (see AGENTS.md, Writing)

The test: does the text get rendered by markdown or git, or does it get read inside the source file? Rendered means no wrap. Read in place means wrap at 120.

## Commit messages

- The repo's own convention wins. Read the last 20 to 30 commits first and match what is there: title-only, conventional commits, issue prefixes, whatever the history shows. The rules below are the default when the repo has no clear convention
- Conventional commit format: `type(scope): summary`, summary in imperative, lowercase, no trailing period, under 80 characters
- Blank line, then the body: why the change exists, not what it does. The diff already shows what
- One paragraph is usually enough. If you need more, each paragraph is one raw line
- No footer, no signature, no `Co-authored-by`, no "generated with" trailer, no session URL. Absolutely no coding agent trace of any kind
- Follow the working repo commit convention

## PR and issue descriptions

- Lead with the problem, then the change, then how it was verified
- Link issues in the description, never in code comments or commit messages
- No checklists unless the project template requires them
- No headings for a description under ten lines

## Punctuation

- No em dashes
- No smart or curly quotes, straight quotes only
- No ellipsis character
- Use a comma, a colon, or a period instead
