# Diagram-Type Playbook

Concrete conventions for named diagram types the abstract Visual Pattern Library in `SKILL.md` doesn't cover on its own. Read the matching entry before generating one of these; combine with the abstract patterns (fan-out, timeline, etc.) inside a single diagram when a type mixes concerns.

## Gantt Chart

- Task list down the left as free-floating text (one row per task).
- Time axis across the top: a horizontal `line` with tick marks (small vertical `line` elements) at each period boundary, period labels as free-floating text above each tick.
- One horizontal `rectangle` bar per task, aligned to its row, `x`/`width` mapped from start/end period to axis pixel position, uniform bar height across all tasks.
- Milestones: small `diamond` shape at the milestone date instead of a bar.
- Today-line: a vertical dashed `line` spanning all rows.
- Critical path: give its bars one accent stroke/fill pair from `color-palette.md`; every other bar uses a single neutral pair. Don't rainbow this diagram type.

## UML Class Diagram

- Each class is a `rectangle` split into three compartments by two internal `line` elements: name (top), attributes (middle), methods (bottom). Use three separate free-floating text blocks positioned inside the compartments rather than one multi-line string, so compartment boundaries stay independent of text length.
- Inheritance: `arrow` with `endArrowhead: "triangle_outline"` pointing at the parent. This is Excalidraw's actual hollow-triangle arrowhead, no hand-built approximation needed.
- Composition: `arrow` with `startArrowhead: "diamond"` (filled) at the owning end.
- Aggregation: `arrow` with `startArrowhead: "diamond_outline"` (unfilled) at the owning end.
- Favor fewer classes with clear relationships over an exhaustive model. The Isomorphism Test applies here too.

## SWOT Analysis

- A 2x2 grid: two perpendicular `line` elements crossing at the center, spanning the full diagram bounds, creating four quadrants.
- Strengths (top-left), Weaknesses (top-right), Opportunities (bottom-left), Threats (bottom-right). This ordering is a real convention, don't rearrange it.
- One fill/stroke pair per quadrant from `color-palette.md`'s semantic set: Strengths uses End/Success, Weaknesses uses Error, Opportunities uses Primary/Neutral, Threats uses Warning/Reset.
- 3-6 short free-floating text items per quadrant, not full sentences.
- Optional axis labels as free-floating text outside the grid: "Helpful"/"Harmful" across the top, "Internal"/"External" down the left, only if the user wants the classic framing spelled out.

## Lean Canvas

- The standard 9-box grid, built from `rectangle` containers. This is one of the few diagram types where nearly everything IS boxed, because the grid structure is the point: Problem, Solution, Key Metrics, Unique Value Proposition (center column, visually dominant, taller or bolder-stroked than its neighbors), Unfair Advantage, Channels, Customer Segments across the top two rows; Cost Structure and Revenue Streams as two wide boxes spanning the bottom row.
- This type is exempt from `SKILL.md`'s Quality Checklist items 9 ("no uniform containers") and 20 ("container ratio under 30%"): a Lean Canvas's uniform grid of boxes is correct here, not a defect to fix.
- Section titles: small uppercase free-floating text pinned to each box's top-left corner, not centered. This is a working canvas, not a poster.
- Content per box: short phrases, one per line, not sentences. Leave visible empty space in each box; a Lean Canvas that looks full looks finished, which undersells that it's meant to be iterated on.

## Wireframes & Mockups

- Grayscale only. Pull fills and strokes from `color-palette.md`'s "Grayscale (Wireframes Only)" table, not the semantic Shape Colors table. This is the one diagram type where the semantic colors are the wrong choice.
- Real label text on every control ("Sign up", not "Button" or lorem ipsum).
- Body copy placeholder: short horizontal `line` elements stacked with row spacing (a squiggle-line effect) in the grayscale table's placeholder color, not actual paragraph text.
- One frame per screen: a large bounding `rectangle` per screen, named via a free-floating text label above it ("Onboarding, step 2"), multiple screens laid out left to right in flow order.
- Annotation callouts: free-floating text outside the frame boundary, in the grayscale table's accent color, pointing in with a thin `arrow`.

## Mind Map

- Central topic: one `ellipse` or free-floating bold text at the diagram center.
- 3-7 main branches radiating outward. This is the Fan-Out pattern already in the core Visual Pattern Library; a mind map is a fan-out with no shapes on the leaves.
- Branch lines: `line` elements, not arrows. Mind maps are non-directional, no arrowheads anywhere in this diagram type.
- One hue per major branch, drawn from `color-palette.md`'s existing stroke colors (Start-orange, End-green, Warning-red, Decision-amber, AI-purple, Primary-navy give six distinct options; cycle back to the first if there are more than six branches), applied to that branch's line and its own leaf text so the eye can trace a leaf back to its top-level branch by color alone.
- `SKILL.md`'s "no more than 3-4 distinct fill colors" budget doesn't bind this entry: branch hues here are stroke and text colors on unfilled lines and free-floating labels, not container fills.
- Leaf labels: free-floating text, single words or short phrases, no containers.

## Roadmap

- Horizontal time axis across the top (quarters or months). Reuse the Gantt chart's axis-line-with-ticks construction above.
- Swimlanes: one per team or theme, as horizontal `line` dividers with a lane label as free-floating text at the left edge of each lane.
- Initiatives: `rectangle` sized roughly proportional to duration, placed in its lane at its start time.
- "Now" marker: a vertical line across all lanes, same construction as the Gantt chart's today-line.
- Color by status: fill color signals planned/in-progress/done. Use `color-palette.md`'s "Status Colors (Roadmap)" table so status colors stay recognizable diagram to diagram.
