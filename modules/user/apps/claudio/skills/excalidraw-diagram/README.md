# excalidraw-diagram (forked)

Base: [coleam00/excalidraw-diagram-skill](https://github.com/coleam00/excalidraw-diagram-skill).

Local patch: `references/render_template.html` pins the esm.sh import to a
working dependency combination — see the inline comment at the import line.

Additions folded in from two other candidates compared in
`forgejo.emx.casa/emaiax/dotfiles#191` (content only, not their remote/account
transport):

- Layout/typography/color-budget numbers, from
  [thomast1906/github-copilot-agent-skills](https://github.com/thomast1906/github-copilot-agent-skills/tree/main/.github/skills/excalidraw-mcp-diagramming)
  (`SKILL.md`, under Layout Principles / Text Rules / Color as Meaning).
- `references/diagram-type-playbook.md`, adapted from the use-case playbook in
  [NicholasSpisak/excalidraw](https://github.com/NicholasSpisak/excalidraw).

## Updating this fork

**Re-syncing from upstream coleam00/excalidraw-diagram-skill:**
1. Clone the upstream repo fresh into a scratch dir.
2. Diff its `references/color-palette.md`, `element-templates.md`,
   `json-schema.md`, `pyproject.toml` against ours — these four are untouched
   by this fork, so any difference is a pure upstream change; review and copy
   over directly.
3. Diff its `SKILL.md` and `references/render_template.html` against ours
   *before* applying anything — these two carry local additions (the
   Layout/Text/Color/playbook sections in `SKILL.md`, the esm.sh patch in
   `render_template.html`), so a raw overwrite silently drops them. Pull in
   upstream's changes to the parts this fork didn't touch, keep the additions.
4. Re-run both fixtures in `test/` after touching `render_template.html` or
   `render_excalidraw.py` — an upstream bump can reintroduce an esm.sh
   resolution break:
   ```
   cd references && uv run python render_excalidraw.py ../test/smoke-test.excalidraw --output /tmp/smoke-test.png
   uv run python render_excalidraw.py ../test/swot-test.excalidraw --output /tmp/swot-test.png
   ```

**If the esm.sh render hangs again** (the `window.__moduleReady` timeout this
fork originally fixed):
1. `curl -sS -o /dev/null -w "%{http_code}\n" <failing-url-from-the-browser-console-error>`
   to confirm which file 404s.
2. Binary-search package versions with the same `curl` check
   (`https://esm.sh/<pkg>@<version>/<path>`) to find the first version that
   serves the missing file.
3. Update the `deps=` query param in `render_template.html`'s import line to
   that version, re-run both fixtures above.

**If Options 2 or 3's upstream skills change their conventions**: this fork
doesn't track them live — the additions from Task 2/3 are a point-in-time
snapshot. Re-visit `SKILL.md`'s "Spacing & Layout Budget" section and
`references/diagram-type-playbook.md` by hand to pull in a later revision;
there's no automated sync.
