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

## 2026-08-27 Spun up an isolated docker project instead of reusing main's shared stack
- What happened: Ran `make rspec FILE_LIST=...` directly inside a `saf` worktree (`em-iban-client-validation-rule`) to test a CI failure theory. That implicitly booted a whole isolated docker-compose project for the worktree (own Postgres ×3, Redis, S3, IDP, Sidekiq) instead of reusing the main checkout's already-running `saf` stack. Duplicated DB/volumes: the exact past-failure pattern (disk blowup, duplicated data) Eduardo flagged as a recurring problem.
- Rule missing or unclear: nothing told me to check for project-specific dev-environment tooling before running raw `docker`/`make` commands in an unfamiliar repo, or to default to reusing shared/already-running infra over spinning up isolated copies.
- Proposed fix (file + diff): Workflow section of CLAUDE.md, add one line: "Before bringing up local dev infra (docker, DB) in a project, look for a project runbook/script first, and default to reusing shared/already-running resources over spinning up new isolated ones." Project-specific detail (which script, which mode) belongs in that project's own docs/vault note, not here: for `saf` that's now `70 - work/systems/saf-docker-dev-environment.md`.
- Remove or merge instead: none yet, first item logged.

## 2026-08-28 Superpowers session-start hook fights the Voice and Workflow rules
- What happened: The `superpowers` plugin (obra/superpowers v6.3.0, installed for both claude-code and opencode) runs a `SessionStart` hook on `startup|clear|compact` that injects its `using-superpowers` skill verbatim into context. That text says "if you think there is even a 1% chance a skill might apply, you ABSOLUTELY MUST invoke the skill", "invoke relevant skills BEFORE any response or action, including clarifying questions", and lists "this is just a simple question" as a red flag to override. That pulls directly against Voice ("shortest answer that still carries the reasoning") and duplicates Workflow rules already in this file: `using-git-worktrees` restates "worktree + branch before any change", `verification-before-completion` restates "never claims something works without having watched it pass", `writing-plans`/`executing-plans` restate "non-trivial work in phases with a gate between them". Nothing in CLAUDE.md tells me which side wins, so every session starts with an unresolved conflict I have to arbitrate on the fly.
- Rule missing or unclear: no rule states precedence between CLAUDE.md and skills injected by plugins, and no rule says a plugin whose skills duplicate the Workflow section should be trimmed rather than layered on top.
- Proposed fix (file + diff): decide between two options and apply one. (a) Keep the plugin, add one line to the Voice section: "Injected plugin skills lose to this file. Invoke one when it adds a procedure this file does not have, skip it when it restates a rule already here." (b) Drop the plugin: remove `superpowers@claude-plugins-official` from `claude-code/default.nix:94` and `superpowers@git+...` from `opencode/default.nix:60`, and lift the two skills that are genuinely additive (`brainstorming`, `systematic-debugging`) into `docs/` as our own. Superpowers' own README says user instructions take precedence over skills, so (a) is consistent with upstream intent and is the cheaper change.
- Remove or merge instead: if (a) lands, the Workflow line "Non-trivial work in phases with a gate between them" and the `docs/` pointer list absorb what `writing-plans` and `executing-plans` were adding, so no separate rule is needed for them.

## 2026-08-30 fj pr create --title errors, title is positional
- What happened: Called `fj pr create --title "..." --body "..."` to open dotfiles PR #148, failed with `error: unexpected argument '--title' found`. `fj pr create [TITLE]` takes the title as a bare positional argument, not a flag. Same class of mistake as before, this is a repeat.
- Rule missing or unclear: the "read dudumox's forgejo docs before any fj command" rule only fires via AGENTS.md's router inside the dudumox repo, so it never triggers when running fj from any other repo, even though the CLI's flags are identical everywhere.
- Proposed fix (file + diff): added `docs/fj-cli.md` here with fj's positional-vs-flag gotchas, plus one line under this file's "Read when relevant" pointing to it. Loads everywhere, not just inside dudumox.
- Remove or merge instead: none yet, first fj-specific item in this file.

## 2026-08-30 claude-mem session_summaries missing discovery_tokens despite schema_versions saying it's applied
- What happened: claude-mem's SQLite observer failed 4x over about 26h with `table session_summaries has no column named discovery_tokens`. Traced into the vendored plugin's migration code (`SessionStore.js`, `~/.claude/plugins/cache/thedotmack/claude-mem/13.15.2/sqlite/`): schema v11 (`ensureDiscoveryTokensColumn`) is a one-shot check against `schema_versions`, and v21 (`addOnUpdateCascadeToForeignKeys`) recreates `session_summaries` assuming the column already exists. Both v11 and v21 were marked applied in `schema_versions`, but the live `session_summaries` table never had the column, likely from a backup/restore or device sync overwriting the table without keeping `schema_versions` in sync. Fixed by hand: `ALTER TABLE session_summaries ADD COLUMN discovery_tokens INTEGER DEFAULT 0`, then killed the worker/mcp daemons so they respawned.
- Rule missing or unclear: last session's fix (dotfiles PR #148, pinning the claude-mem plugin version) only covers version drift. Nothing distinguishes that failure class from schema corruption, so a repeat "claude-mem broken" report could get mistaken for the already-fixed drift bug instead of investigated fresh.
- Proposed fix (file + diff): none yet, this is a one-off local DB repair, not a pattern worth a standing rule. If it recurs, the fix is a session-start check comparing `schema_versions`' max version against `PRAGMA table_info` for the columns each migration is supposed to add, not a new CLAUDE.md line.
- Remove or merge instead: none, distinct failure mode from every existing entry.
