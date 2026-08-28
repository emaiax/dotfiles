# Writing

Applies to any prose that ends up rendered by markdown or git, or read by another human or agent: commit message bodies, PR and issue descriptions, review comments, design docs, ADRs, READMEs, runbooks, skill and instruction files, multi-sentence comments in config files.

Sections 1 to 7 are voice and structure, they apply to everything. "Commit messages" and "PR and issue descriptions" add rules for those two artifacts. "Never hard-wrap" and "Punctuation" are mechanics. "Before you ship" is the checklist.

## Opening

- First sentence states what the document is and does. No warm-up, no history of the problem.

  Bad: "This document aims to provide an overview of the considerations involved in migrating the auth service."
  Good: "This runbook migrates the auth service from opaque tokens to JWT. Run it during a maintenance window."

- State the core principle or decision once, early, in one sentence. Everything after it is elaboration.
- If different readers need different parts, route them in the opening: "Sections 1 to 3 explain how the system works, read them before touching anything. Sections 4 to 6 are the procedure."
- When a doc describes code or config, name the source of truth and which wins on disagreement: "When this guide and the code disagree, the code wins. Fix the guide."

## Audience

- Assume the reader is smart and busy. Assume they know the language and the tools, and nothing about this repo's specifics.
- Cut every sentence the reader already knows. Each paragraph must justify its cost.

  Bad: "Redis is an in-memory key-value store often used for caching. We use it for session data, and this PR shortens the TTL."
  Good: "Session cache TTL drops from 24h to 1h. Revoked role grants were surviving a full day."

- Make each section self-contained enough to act on. Readers arrive out of order, so repeat the command rather than write "same as above".

## Sentences

- Imperative mood for anything the reader should do. "Run the migration", never "the migration should be run".
- One idea per sentence. Short sentences. Fragments are fine.
- Attach the reason to the rule in the same line, compressed.

  Bad: "Do not retry on 4xx."
  Good: "Do not retry on 4xx: the request is malformed and fails identically every time."

- Report status as what you ran and what you saw. "Should", "probably", and "seems to" are not status.

  Bad: "This should fix the flaky upload test."
  Good: "Ran `pytest tests/test_upload.py` 20 times after the fix: 20 passes."

- State failure as plainly as success.

  Bad: "Mostly working, a couple of edge cases remain."
  Good: "3 of 5 acceptance criteria pass. Unicode filenames and empty uploads still fail, both reproduce with `pytest -k edge`."

- Claims about external tools, versions, or APIs carry a link or the label unverified.

## Structure

- Headings are an index. Name each one by its content so a reader scanning only headings still gets the argument.

  Bad: "## Notes", "## Details", "## Miscellaneous"
  Good: "## No placeholders", "## Rollback", "## When not to use this"

- Decision rules go in a two-column table: situation, action. Prose buries them.
- Procedures go in numbered steps, one action per step, each one checkable on its own.
- Reference material goes in tables or lists, never flowing prose.
- Cross-reference other docs by name. Never duplicate their content.

## Concreteness

- Exact paths, exact commands, exact values. "The config file" is a search, `config/deploy/production.yml` is an answer.
- Every command comes with its expected output.

  Bad: "Verify the service is healthy."
  Good: "Run `curl -s localhost:8080/health`. Expected: `{\"status\":\"ok\"}`."

- Show one bad example next to one good example, each with a one-line reason underneath. One excellent example beats three mediocre ones.
- Placeholders are failures: "TBD", "add appropriate error handling", "similar to the above", any step that describes what to do without showing how.
- When explaining a change, drop into the code or the diff instead of paraphrasing it.

## Anticipate the reader

- Name the shortcut the reader will want, and answer it at the point where they will want it: "The migration is additive, so skipping the backup looks safe. Take the backup. The last outage started here."
- State when the document does not apply. A scope without a boundary gets applied everywhere.
- Close loopholes by naming them.

  Bad: "Do not merge without review."
  Good: "Do not merge without review. Self-approval is not review. A thumbs-up emoji is not review."

- Write exceptions as their own explicit condition, keyed to something observable. A trailing "unless it matters" reopens the negotiation.

  Bad: "Pin dependencies unless it's impractical."
  Good: "Pin dependencies. Exception: packages released from this monorepo, which version together."

## Arguing for a decision (design docs, ADRs, proposals)

- Lead with your recommendation and its reason. Follow with the alternatives, each with its trade-off, so the reader can check your work.
- Scale each section to its complexity: a settled point gets two sentences, a contested one gets a paragraph.
- Run every requirement through the two-readings test: if it can be read two ways, pick one and write that.

## Commit messages

- The repo's own convention wins. Read the last 20 to 30 commits first and match what is there: title-only, conventional commits, issue prefixes, whatever the history shows. The rules below are the default when the repo has no clear convention
- Conventional commit format: `type(scope): summary`, summary in imperative, lowercase, no trailing period, under 80 characters
- Blank line, then the body: why the change exists, not what it does. The diff already shows what
- One paragraph is usually enough. If you need more, each paragraph is one raw line
- No footer, no signature, no `Co-authored-by`, no "generated with" trailer, no session URL. Absolutely no coding agent trace of any kind

## PR and issue descriptions

- Lead with the problem, then the change, then how it was verified
- Link issues in the description, never in code comments or commit messages
- No checklists unless the project template requires them
- No headings for a description under ten lines

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
- A comment in source code is part of the code, not a prose artifact. Comments wrap at 120 columns, or at the project's own limit when it sets one

The test: does the text get rendered by markdown or git, or does it get read inside the source file? Rendered means no wrap. Read in place means wrap.

## Punctuation

- No em dashes
- No smart or curly quotes, straight quotes only
- No ellipsis character
- Use a comma, a colon, or a period instead

## Before you ship

Reread with fresh eyes and check:

- [ ] First sentence says what this is.
- [ ] No placeholder text, no step that hides "figure it out" behind a summary.
- [ ] No section contradicts another. Names, signatures, and values match across sections.
- [ ] Every success claim points at output you watched this session.
- [ ] Every command has an expected result next to it.
- [ ] Nothing duplicates another doc.
- [ ] No hard-wrapped paragraphs, no em dashes, no curly quotes, no agent trace in commit or PR text.
- [ ] Anything that could be cut is cut.
