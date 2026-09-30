# Diagram-Type Playbook

Concrete conventions for named diagram types the abstract Visual Pattern
Library in `SKILL.md` doesn't cover on its own. Read the matching entry
before generating one of these; combine with the abstract patterns
(fan-out, timeline, etc.) inside a single diagram when a type mixes
concerns.

## Gantt Chart
- Task list down the left as free-floating text (one row per task).
- Time axis across the top: a horizontal `line` with tick marks (small
  vertical `line` elements) at each period boundary, period labels as
  free-floating text above each tick.
- One horizontal `rectangle` bar per task, aligned to its row, `x`/`width`
  mapped from start/end period to axis pixel position, uniform bar height
  across all tasks.
- Milestones: small `diamond` at the milestone date instead of a bar.
- Today-line: a vertical dashed `line` spanning all rows.
- Critical path: give its bars one accent stroke/fill pair from
  `color-palette.md`; every other bar uses a single neutral pair — don't
  rainbow this diagram type.

## UML Class Diagram
- Each class is a `rectangle` split into three compartments by two
  internal `line` elements: name (top), attributes (middle), methods
  (bottom). Use three separate free-floating text blocks positioned
  inside the compartments rather than one multi-line string, so
  compartment boundaries stay independent of text length.
- Inheritance: `arrow` pointing at the parent. Excalidraw's arrowhead
  vocabulary has no hollow-triangle head — approximate with
  `endArrowhead: "triangle"` and tell the user the outline-vs-filled
  distinction isn't renderable if it matters for their diagram.
- Composition/aggregation: `diamond` at the owning end of the line,
  filled for composition, left as an unfilled small diamond for
  aggregation.
- Favor fewer classes with clear relationships over an exhaustive model
  — the Isomorphism Test applies here too.

## SWOT Analysis
- A 2x2 grid: two perpendicular `line` elements crossing at the center,
  spanning the full diagram bounds, creating four quadrants.
- Strengths (top-left), Weaknesses (top-right), Opportunities
  (bottom-left), Threats (bottom-right) — this ordering is a real
  convention, don't rearrange it.
- One fill/stroke pair per quadrant from `color-palette.md`'s semantic
  set (e.g. Strengths/End-green, Weaknesses/Error-red,
  Opportunities/Primary, Threats/Warning).
- 3-6 short free-floating text items per quadrant, not full sentences.
- Optional axis labels as free-floating text outside the grid:
  "Helpful"/"Harmful" across the top, "Internal"/"External" down the
  left, only if the user wants the classic framing spelled out.

## Lean Canvas
- The standard 9-box grid, built from `rectangle` containers — one of
  the few diagram types where nearly everything IS boxed, because the
  grid structure is the point: Problem, Solution, Key Metrics, Unique
  Value Proposition (center column, visually dominant — taller or
  bolder-stroked than its neighbors), Unfair Advantage, Channels,
  Customer Segments across the top two rows; Cost Structure and Revenue
  Streams as two wide boxes spanning the bottom row.
- Section titles: small uppercase free-floating text pinned to each
  box's top-left corner, not centered — this is a working canvas, not a
  poster.
- Content per box: short phrases, one per line, not sentences. Leave
  visible empty space in each box; a Lean Canvas that looks full looks
  finished, which undersells that it's meant to be iterated on.

## Wireframes & Mockups
- Grayscale only — pull fills from a neutral gray scale, not the
  semantic color palette. This is the one diagram type where
  `color-palette.md`'s semantic colors are the wrong choice.
- Real label text on every control ("Sign up", not "Button" or lorem
  ipsum).
- Body copy placeholder: short horizontal `line` elements stacked with
  row spacing (a squiggle-line effect), not actual paragraph text.
- One frame per screen: a large bounding `rectangle` per screen, named
  via a free-floating text label above it ("Onboarding — step 2"),
  multiple screens laid out left to right in flow order.
- Annotation callouts: free-floating text outside the frame boundary, in
  a single accent color, pointing in with a thin `arrow`.

## Mind Map
- Central topic: one `ellipse` or free-floating bold text at the diagram
  center.
- 3-7 main branches radiating outward — this is the Fan-Out pattern
  already in the core Visual Pattern Library; a mind map is a fan-out
  with no shapes on the leaves.
- Branch lines: `line` elements, not arrows — mind maps are
  non-directional, no arrowheads anywhere in this diagram type.
- One hue per major branch, applied consistently to that branch's own
  sub-nodes, so the eye can trace a leaf back to its top-level branch by
  color alone.
- Leaf labels: free-floating text, single words or short phrases, no
  containers.

## Roadmap
- Horizontal time axis across the top (quarters or months) — reuse the
  Gantt chart's axis-line-with-ticks construction above.
- Swimlanes: one per team or theme, as horizontal `line` dividers with a
  lane label as free-floating text at the left edge of each lane.
- Initiatives: `rectangle` sized roughly proportional to duration,
  placed in its lane at its start time.
- "Now" marker: a vertical line across all lanes, same construction as
  the Gantt chart's today-line.
- Color by status: fill color signals planned/in-progress/done — reuse a
  single three-color set for this across every roadmap so status colors
  stay recognizable diagram to diagram.
