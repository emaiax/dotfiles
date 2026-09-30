# Color Palette & Brand Style

**This is the single source of truth for all colors and brand-specific styles.** To customize diagrams for your own brand, edit this file — everything else in the skill is universal.

---

## Shape Colors (Semantic)

Colors encode meaning, not decoration. Each semantic purpose has a fill/stroke pair.

| Semantic Purpose | Fill | Stroke |
|------------------|------|--------|
| Primary/Neutral | `#3b82f6` | `#1e3a5f` |
| Secondary | `#60a5fa` | `#1e3a5f` |
| Tertiary | `#93c5fd` | `#1e3a5f` |
| Start/Trigger | `#fed7aa` | `#c2410c` |
| End/Success | `#a7f3d0` | `#047857` |
| Warning/Reset | `#fee2e2` | `#dc2626` |
| Decision | `#fef3c7` | `#b45309` |
| AI/LLM | `#ddd6fe` | `#6d28d9` |
| Inactive/Disabled | `#dbeafe` | `#1e40af` (use dashed stroke) |
| Error | `#fecaca` | `#b91c1c` |

**Rule**: Always pair a darker stroke with a lighter fill for contrast.

---

## Text Colors (Hierarchy)

Use color on free-floating text to create visual hierarchy without containers.

| Level | Color | Use For |
|-------|-------|---------|
| Title | `#1e40af` | Section headings, major labels |
| Subtitle | `#3b82f6` | Subheadings, secondary labels |
| Body/Detail | `#64748b` | Descriptions, annotations, metadata |
| On light fills | `#374151` | Text inside light-colored shapes |
| On dark fills | `#ffffff` | Text inside dark-colored shapes |

---

## Evidence Artifact Colors

Used for code snippets, data examples, and other concrete evidence inside technical diagrams.

| Artifact | Background | Text Color |
|----------|-----------|------------|
| Code snippet | `#1e293b` | Syntax-colored (language-appropriate) |
| JSON/data example | `#1e293b` | `#22c55e` (green) |

---

## Default Stroke & Line Colors

| Element | Color |
|---------|-------|
| Arrows | Use the stroke color of the source element's semantic purpose |
| Structural lines (dividers, trees, timelines) | Primary stroke (`#1e3a5f`) or Slate (`#64748b`) |
| Marker dots (fill + stroke) | Primary fill (`#3b82f6`) |

---

## Grayscale (Wireframes Only)

The one diagram type that doesn't pull from the semantic table above. See `references/diagram-type-playbook.md`'s Wireframes & Mockups entry.

| Use | Color |
|-----|-------|
| Screen/control container fill | `#f1f5f9` |
| Container/control stroke | `#64748b` (reuses the Slate value from Text Colors above) |
| Body-copy placeholder lines | `#cbd5e1` |
| Annotation callout accent | `#b45309` (reuses the Decision stroke above) |

---

## Status Colors (Roadmap)

Reuses three existing semantic rows from the Shape Colors table above. See `references/diagram-type-playbook.md`'s Roadmap entry.

| Status | Semantic row to reuse |
|--------|------------------------|
| Planned | Inactive/Disabled (`#dbeafe` / `#1e40af`, dashed stroke) |
| In progress | Decision (`#fef3c7` / `#b45309`) |
| Done | End/Success (`#a7f3d0` / `#047857`) |

---

## Background

| Property | Value |
|----------|-------|
| Canvas background | `#ffffff` |
