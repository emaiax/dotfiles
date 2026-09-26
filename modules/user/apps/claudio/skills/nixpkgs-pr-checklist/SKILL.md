---
name: nixpkgs-pr-checklist
description: Use when preparing, rebasing, or finishing a Nixpkgs pull request before requesting review, including after fixing CI/lint failures, running nixpkgs-review, or about to commit/push a nixpkgs branch.
---

# Nixpkgs PR Checklist

## Overview

Contributor-side diligence for Nixpkgs PRs: verify your part (build, tests,
format, lint, meta, release notes) is actually solid before a human reviewer
looks at it. Not for release engineering: staging merges, backports, and
Hydra coordination are out of scope.

Core principle: **verified beats assumed.** Only report a checklist item as
done when you ran the command yourself in this session and saw it pass.

## When to Use

Rebasing a nixpkgs branch, CI (lint/parse/nixpkgs-vet/build/eval) failing or
just turned green, about to run `nixpkgs-review`, about to commit/push a
nixpkgs branch, or filling in the PR template's "Things done" checkboxes.

Not for: staging/staging-next workflow, backports, Hydra/channels, that's
release-engineering, a different job.

## Guardrails

Violating the letter of these rules is violating the spirit of them, so treat
every commit, push, `--post-result`, `--approve-pr`, and `--merge-pr` as its
own decision, never implied by an earlier one.

1. **Never `git commit` or `git push` without the user explicitly accepting a
   concrete proposal.** Show the exact commit message (or diff) and wait for
   an explicit yes, every single time, including follow-up fixes discovered
   later in the same session. An earlier approval covers only what was shown
   at the time.
2. **Never pass `--post-result`, `--approve-pr`, or `--merge-pr` to
   `nixpkgs-review`.** Always run `--print-result --no-shell`, read the
   output yourself, and report it back in chat as text. This holds even when
   the user asks to "leave it recorded" or "make it visible", that means
   visible to *them*, not posted to GitHub. Only use `--post-result` if the
   user says, in those words, to post a PR comment.

| Excuse | Reality |
|---|---|
| "User asked to make it visible/recorded" | Visible to the user (text you report) ≠ visible on GitHub. Default `--print-result`. |
| "They already said 'segue o baile' / 'tá bom' earlier" | Consent is scoped to the specific diff shown then, not a standing license for what you find next. |
| "It's a tiny, mechanical fix" | Size doesn't matter, still show it and wait. |
| "CI is green, obviously ready" | Green CI is a build signal, not consent. |

**Red flags, stop and ask:**
- About to run `git commit`/`git push` without having shown the exact
  message/diff and gotten a yes *this turn*
- About to run `nixpkgs-review` with `--post-result`, `--approve-pr`, or
  `--merge-pr`
- Treating silence, an emoji, or an unrelated earlier "looks good" as
  consent for a new action

## Checklist

Full commands and rationale: [references/checklist.md](references/checklist.md).

1. Scope: diff against merge-base to find touched packages/modules
2. Branch hygiene: not on master; rebased onto latest upstream/master
3. Format/parse: `nix fmt -- --fail-on-change`, `nix-instantiate --parse`
4. Build: per platform claimed in the PR template
5. Package tests: `passthru.tests`
6. NixOS module tests: `nixosTests.<name>` (macOS needs a Linux builder for
   `kvm`/`apple-virt`; missing that is an environment limit, not a failure,
   never silently check this box without running it)
7. New/changed lints: nixpkgs-vet and friends drift fast; don't assume last
   month's rules still apply
8. `nixpkgs-review pr <N> --print-result --no-shell` (or `wip` for
   uncommitted changes), see Guardrails
9. Smoke-test binaries in `result/bin`
10. `meta` compliance: license, mainProgram, maintainers, platforms
11. Release-notes convention: grep the current `rl-*.section.md` for a
    recent analogous module/package addition; flag if yours is missing
12. Commit hygiene: one logical commit per unit, conventional prefix, no
    trailing period, separate `maintainers: add` commit if needed
13. Map results back onto the PR template checkboxes, only check what you
    verified this session
14. Post-push CI triage: pull the actual failure log before proposing a
    fix; distinguish a real regression from rebase/reformat noise or a
    GitHub API hiccup (e.g. `mergeable: UNKNOWN` timing out) before acting

Common mistakes (rebase-conflict noise, release-notes-not-needed assumption,
stale test verification): [references/checklist.md](references/checklist.md#common-mistakes).
