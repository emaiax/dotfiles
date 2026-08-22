# Profile test suite

AFK test suite for the Claude Code profiles defined in this module: `claude` (default sandboxed), `claudio`, `claudio-thebot`, and `claude-yolo`. Every dynamic case runs identically against all four profiles; per-profile expectations live in `expected/<profile>.tsv`, so the comparison sandboxed × yolo falls out of the same run.

## Running

```
tests/run.sh                 # everything: static + dynamic probes
tests/run.sh --static-only   # config assertions only, no claude sessions, no cost
tests/run.sh --profile claude-yolo --case 'gate-*'   # subset
tests/run.sh --jobs 8        # probe parallelism (default 5)
```

Requirements: `jq`, `git`, `nix`, bash >= 5 on PATH (the repo's home-manager env provides all of them). Dynamic probes spawn real headless `claude -p` sessions on the model in `$TESTS_MODEL` (default `haiku`); a full run is ~75 sessions, a few US dollars, 30-45 minutes at the default parallelism.

## What is tested, and how

- **Static (`10-static-settings.sh`, `50-automode.sh`)**: the branch's generated artifacts, resolved via `nix build` of the home-manager activation package, never the activated system. Asserts the base `settings.json` (sandbox rules, permission gates, network policy) and each profile's overlay JSON and wrapper flags, including every auto-mode layer (`environment`, `soft_deny`, thebot's `allow` override). Auto-mode is prose judged by a model, not mechanical enforcement, so config-level validation is the honest limit of what can be asserted deterministically; behavioral soft-deny probes were considered and rejected as flaky-by-construction.
- **Dynamic (`20-sandbox-fs.sh`, `30-sandbox-net.sh`, `40-permission-gates.sh`)**: real enforcement, observed from side effects. Each case either wraps its payload in a generated `case.sh` (sandbox semantics apply to children; the wrapper also gives deterministic exit/stdout/stderr artifacts) or hands the model the literal command (permission rules match on the top-level command string, so gate cases must not be wrapped). Verdicts come from artifacts (marker files, bare-remote refs, the `permission_denials` array in the session JSON), never from the probe model's self-report.

## Design constraints worth knowing

- Destructive payloads (`git push`, `rm -rf`, `git reset --hard`) only ever touch throwaway fixture repos with a local bare remote, created per-case under `$TMPDIR`. Nothing probes a real remote or this repo.
- The dynamic layer tests the branch's profile wrappers over the **machine's active base** `~/.claude/settings.json` (the base is only swapped by `just switch`, which needs sudo). `run.sh` diffs the active base against the branch's and reports the drift in `compare.md`; static assertions always target the branch artifacts, so a drifted key is still caught there.
- Probe sessions load the real user config (hooks, plugins, CLAUDE.md) on purpose: the rtk PreToolUse hook rewriting commands is part of the system under test, not noise.
- `XFAIL_*` verdicts in the expected tables mark known, justified divergences; the note column points at the code comment carrying the justification.

## Layout

```
run.sh            orchestrator: preflight, static, parallel probe queue, summary + compare.md
lib/harness.sh    result recording (results.jsonl), assertions, expected-table lookup, timeout
lib/build.sh      nix build resolution of wrappers/overlays/base, active-base drift check
lib/fixtures.sh   throwaway git repos with local bare remotes
lib/probe.sh      headless claude -p invocation, artifact collection, verdict extraction
suites/           test definitions (see above)
expected/         one TSV per profile: case_id, verdict, note
results/          gitignored; one dir per run + `latest` symlink
```
