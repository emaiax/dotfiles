# Nixpkgs PR Checklist: Full Commands

Detailed version of the 14-step checklist in SKILL.md. Run these for real;
don't infer results from memory of a previous session.

## 1. Scope

```
git merge-base <branch> upstream/master
git diff --name-only <merge-base> <branch>
```

## 2. Branch hygiene

```
git branch --show-current   # must not be master/main
git fetch upstream master
git rebase upstream/master  # or upstream/<target-branch>
```

If conflicts appear in a file that's clearly been mechanically reformatted
upstream (e.g. a whole block converted from `name = { ... };` to
`name = { ... }: { ... };`), don't trust the conflict markers line-by-line,
diff your target commit against the pre-rebase merge-base to see exactly
what content you're supposed to add, then reconstruct that insertion against
the *current* upstream file directly.

## 3. Format / parse

```
nix fmt -- --fail-on-change $(git diff --name-only <merge-base> HEAD)
for f in $(git diff --name-only <merge-base> HEAD); do
  nix-instantiate --parse "$f" > /dev/null || echo "FAIL: $f"
done
```

## 4. Build

```
nix build -L .#<attr> --no-link
```
Repeat per platform claimed in the PR template's "Built on platform(s)".

## 5. Package tests

```
nix build -L .#<attr>.tests --no-link
# or: nix-build -A pkgs.<attr>.passthru.tests
```
If a package links a NixOS test via `passthru.tests = { inherit
(nixosTests.X) Y; };`, that satisfies both this box and #6 once #6 is run.

## 6. NixOS module tests

```
nix build -L .#nixosTests.<name> --no-link
```
Requires `kvm` (Linux) or `apple-virt` (macOS, via a configured Linux
builder, e.g. nix-darwin's `nix.linux-builder.enable`). On macOS without
that set up, this will fail for environment reasons, not code reasons, so say
so explicitly, don't check the box, and don't call it a code bug either.

## 7. New/changed lints

Nixpkgs lint rules change over time (new nixpkgs-vet checks, structuredAttrs
requirements, etc.). If a lint fails that predates your branch's base commit
by months, check whether it's a *new* requirement rather than something you
broke: search recently-touched sibling packages for the pattern they now
use (e.g. `grep -rl "__structuredAttrs = true" pkgs/by-name/`) before writing
a fix from scratch.

## 8. nixpkgs-review

```
nix shell nixpkgs#nixpkgs-review --run "nixpkgs-review pr <N> --print-result --no-shell"
# uncommitted local changes:
nix shell nixpkgs#nixpkgs-review --run "nixpkgs-review wip --print-result --no-shell"
```
Never `--post-result` / `--approve-pr` / `--merge-pr`, see SKILL.md
Guardrails. Read the printed markdown yourself and summarize it back to the
user in chat.

## 9. Binary smoke test

```
./result/bin/<mainProgram> --help   # or the minimal meaningful invocation
```

## 10. `meta` compliance

Check against `pkgs/README.md#meta-attributes`: `description` (no leading
"A"/"An", no trailing period, not just the package name), `license`,
`maintainers`, `mainProgram` if it ships an executable, `homepage`.

## 11. Release-notes convention

```
ls nixos/doc/manual/release-notes/ | tail -3   # find current dev-cycle file
grep -n "<analogous keyword, e.g. exporter>" nixos/doc/manual/release-notes/rl-<current>.section.md
```
If a recent, similarly-scoped addition (same category, e.g. another
Prometheus exporter) has an entry under "New Modules" and yours doesn't,
draft one in the same format and flag it to the user before adding.

## 12. Commit hygiene

- One logical commit per unit; squash trivial fixups
  (`git commit --fixup=<sha>` + `git rebase -i --autosquash <base>`)
- No trailing period on the summary line
- `maintainers: add <handle>` as its own commit, before the package commit,
  if the maintainer isn't already in `maintainers/maintainer-list.nix`
- Conventional, imperative mood: "Fix bug" not "Fixed bug"

## 13. Map to PR template

Go through the PR body's "Things done" checkboxes one by one. For each,
either cite the command you ran this session that verifies it, or leave it
unchecked and say why (not applicable, not run, environment limitation).

## 14. Post-push CI triage

```
gh pr view <N> --repo NixOS/nixpkgs --json statusCheckRollup,mergeable,headRefOid
```
For any FAILURE, pull the real log before proposing a fix:
```
gh api /repos/NixOS/nixpkgs/actions/jobs/<job-id>/logs
```
Distinguish:
- **Real regression**: the log shows your change caused it. Fix it.
- **Rebase/reformat noise**: a lint/parse failure in a file you touched but
  whose content you didn't actually author; the file just needs
  reformatting to current conventions.
- **Hiccup**: e.g. a `Test / prepare` job timing out while polling GitHub's
  own mergeability computation ("GitHub is still computing whether this PR
  can be merged... Not retrying anymore"). Confirm by checking `mergeable`
  directly via `gh pr view`, if it now resolves to `MERGEABLE`, the
  underlying state is fine and the job's retry loop just gave up too early.
  Required "PR" workflow checks matter; auxiliary "Test" workflow jobs
  usually don't block merge, so say so, don't treat it as a blocker.

## Common Mistakes

- **Treating a big rebase conflict as needing line-by-line manual merge.**
  If the diff looks like a mechanical reformat collided with your change
  (e.g. a whole file's structure shifted), rebuild the conflicted region from
  the current upstream file plus your real change instead of hand-merging
  garbled hunks.
- **Assuming a small module doesn't need a release-notes entry.** Check the
  current cycle's file for a recent same-category addition before deciding.
- **Marking a NixOS test checkbox from a prior manual run instead of this
  session's.** Lint rules and base commits move; re-verify.
