# excalidraw-diagram (forked)

Base: [coleam00/excalidraw-diagram-skill](https://github.com/coleam00/excalidraw-diagram-skill).

## Setup

```
cd references
uv sync
uv run playwright install chromium
```

## Local patches (all diffs from upstream)

- `references/render_template.html`: pins the esm.sh import to a working dependency combination. See the inline comment at the import line.
- `references/json-schema.md`: the `startArrowhead`/`endArrowhead` rows were stale upstream (missing `triangle_outline`, `diamond`, `diamond_outline`, `circle`, `circle_outline`, `crowfoot_*`). Updated to match the pinned `@excalidraw/excalidraw@0.18.1` library's actual `Arrowhead` type.
- `references/render_excalidraw.py`: added `page.on("console", ...)`, `page.on("pageerror", ...)`, and `page.on("response", ...)` listeners so a hung or failed render prints the actual browser-side error, and the failing URL itself, to stderr, instead of a bare timeout. Also pointed the two "not installed" error messages at `Path(__file__).parent` instead of a hardcoded project-relative path (this fork installs at a user-level path, not a project-local one, see below).
- `SKILL.md`: six new sections, all under headings that don't exist upstream, so a diff against upstream's `SKILL.md` finds them cleanly: "Spacing & Layout Budget" (under Layout Principles), "Element Paint Order" (under JSON Structure), a "Minimum sizes" line (under Text Rules), a "Fill palette budget" line (under Color as Meaning), "Before You Render: Dangling-Binding Check" (under Large/Comprehensive Diagram Strategy), and the "Fork note" plus playbook pointer added in this same pass.
- `references/color-palette.md`: two new tables, "Grayscale (Wireframes Only)" and "Status Colors (Roadmap)", feeding the new playbook entries below.
- `references/diagram-type-playbook.md`: new file, doesn't exist upstream.
- `references/uv.lock`, `test/`: fork-local, no upstream counterpart. Upstream's own `.gitignore` excludes `uv.lock`; this fork tracks it instead, since the skill's working directory is this dotfiles git tree via `mkOutOfStoreSymlink`, and an untracked-but-present lockfile would silently diverge from what's committed.

Additions folded in from two other candidates compared in `forgejo.emx.casa/emaiax/dotfiles#191` (content only, not their remote/account transport):

- Layout/typography/color-budget numbers, from [thomast1906/github-copilot-agent-skills](https://github.com/thomast1906/github-copilot-agent-skills/tree/main/.github/skills/excalidraw-mcp-diagramming) (folded into `SKILL.md`, see the Local Patches list above for exact section names).
- `references/diagram-type-playbook.md`, adapted from the use-case playbook in [NicholasSpisak/excalidraw](https://github.com/NicholasSpisak/excalidraw).

## Updating this fork

**Re-syncing from upstream coleam00/excalidraw-diagram-skill:**

1. Clone the upstream repo fresh into a scratch dir.
2. Diff its `references/color-palette.md` and `element-templates.md` against ours. These two are untouched by this fork beyond the two new tables noted above, so most of any diff is a pure upstream change; review and merge by hand.
3. Diff `SKILL.md`, `references/json-schema.md`, `references/render_template.html`, and `references/render_excalidraw.py` against ours *before* applying anything. All four carry local additions listed in "Local patches" above, so a raw overwrite silently drops them. Pull in upstream's changes to the parts this fork didn't touch, keep every local patch.
4. Re-run both fixtures in `test/` after touching `render_template.html` or `render_excalidraw.py`, since an upstream bump can reintroduce an esm.sh resolution break:

```
cd references
uv run python render_excalidraw.py ../test/smoke-test.excalidraw --output /tmp/smoke-test.png
uv run python render_excalidraw.py ../test/swot-test.excalidraw --output /tmp/swot-test.png
```

**If the esm.sh render hangs again** (the `window.__moduleReady` timeout this fork originally fixed): the render command now prints a `[page response <status>] <url>` line to stderr for any failed request, plus `[page console error]` and `[page error]` lines for related JS errors. Read the `[page response ...]` line first, it names the exact failing URL.

1. `curl -sS -o /dev/null -w "%{http_code}\n" <the URL from the [page response ...] line>` to confirm the failure.
2. Binary-search package versions with the same `curl` check (`https://esm.sh/<pkg>@<version>/<path>`) to find the first version that serves the missing file.
3. Update the `deps=` query param in `render_template.html`'s import line to that version (add a second `,pkg@version` entry if more than one transitive dependency is broken), re-run both fixtures above.

**If Options 2 or 3's upstream skills change their conventions**: this fork doesn't track them live, the additions above are a point-in-time snapshot. Re-visit `SKILL.md`'s "Spacing & Layout Budget" section and `references/diagram-type-playbook.md` by hand to pull in a later revision; there's no automated sync.
