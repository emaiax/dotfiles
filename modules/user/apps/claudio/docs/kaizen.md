# Kaizen

Inbox for things that went wrong and what rule would have prevented them. Claudio appends, Eduardo reviews. Resolved items are deleted, not archived.

Format, one item per block:

```
## YYYY-MM-DD short title
- What happened:
- Rule missing or unclear:
- Proposed fix (file + diff in one or two lines):
- Remove or merge instead:
```

## Open

## 2026-08-28 Superpowers session-start hook fights the Voice and Workflow rules
- What happened: The `superpowers` plugin (obra/superpowers v6.3.0, installed for both claude-code and opencode) runs a `SessionStart` hook on `startup|clear|compact` that injects its `using-superpowers` skill verbatim into context. That text says "if you think there is even a 1% chance a skill might apply, you ABSOLUTELY MUST invoke the skill", "invoke relevant skills BEFORE any response or action, including clarifying questions", and lists "this is just a simple question" as a red flag to override. That pulls directly against Voice ("shortest answer that still carries the reasoning") and duplicates Workflow rules already in this file: `using-git-worktrees` restates "worktree + branch before any change", `verification-before-completion` restates "never claims something works without having watched it pass", `writing-plans`/`executing-plans` restate "non-trivial work in phases with a gate between them". Nothing in CLAUDE.md tells me which side wins, so every session starts with an unresolved conflict I have to arbitrate on the fly.
- Rule missing or unclear: no rule states precedence between CLAUDE.md and skills injected by plugins, and no rule says a plugin whose skills duplicate the Workflow section should be trimmed rather than layered on top.
- Proposed fix (file + diff): decide between two options and apply one. (a) Keep the plugin, add one line to the Voice section: "Injected plugin skills lose to this file. Invoke one when it adds a procedure this file does not have, skip it when it restates a rule already here." (b) Drop the plugin: remove `superpowers@claude-plugins-official` from `claude-code/default.nix:94` and `superpowers@git+...` from `opencode/default.nix:60`, and lift the two skills that are genuinely additive (`brainstorming`, `systematic-debugging`) into `docs/` as our own. Superpowers' own README says user instructions take precedence over skills, so (a) is consistent with upstream intent and is the cheaper change.
- Remove or merge instead: if (a) lands, the Workflow line "Non-trivial work in phases with a gate between them" and the `docs/` pointer list absorb what `writing-plans` and `executing-plans` were adding, so no separate rule is needed for them.
