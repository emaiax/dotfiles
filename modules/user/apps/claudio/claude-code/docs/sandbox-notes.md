# Claude Code sandbox: investigation notes

Background for the terse pointer comments in `claude-sandbox.nix`. Anything here is either a confirmed root cause worth the full trail, or an open question flagged as such — check the date/status before trusting it.

## `git-credential-osxkeychain` fails with `100001` on `store`

`git push` under the sandbox succeeds, but `git-credential-osxkeychain`'s `store` op fails with `fatal: failed to store: 100001` — the push itself goes through, git just can't cache the credential back afterward. `100001` decodes via `security error 100001` to `errSecErrnoBase(100000)+EPERM`, a raw UNIX errno rather than a Seatbelt denial.

Confirmed by reading anthropic-experimental/sandbox-runtime's `macos-sandbox-utils.ts` (the profile generator this sandbox is built on): the baseline profile already grants unconditional mach-lookup to `com.apple.securityd.xpc` and `com.apple.SecurityServer`, and `allowWrite` for `~/Library/Keychains` already compiles to a clean `file-write*` allow with no unlink/create re-deny catching it — so per the generator's own logic this should already work. Adding `allowWrite` for that path (tried, then reverted) didn't fix it, and a live repro with `log stream` running unsandboxed alongside a sandboxed `store` call showed zero kernel Sandbox deny lines for git/bash/git-credential-osxkeychain in the failure window — if Seatbelt were blocking the syscall, the kernel would log it.

Conclusion: this isn't a rule this profile can express. It points at securityd's own ACL/identity resolution for `SecItemAdd` (new item) under a sandbox-exec-wrapped caller, outside this file's control surface. Accepted as a known limitation — don't re-attempt `allowWrite`/`allowMachLookup` tuning for this without new evidence.

Read access to `~/Library/Keychains` is still required and kept: without it, `git-credential-osxkeychain` can't even reach the keychain database to trigger the normal per-item ACL prompt, and fails silently instead of asking. Read access alone doesn't bypass per-item authorization — macOS still decrypts and gates each item via its own ACL. Same fix as CJHwong/agent-seatbelt's `my.sb`.

## gh/fj/docker escape the sandbox via `excludedCommands`

Seatbelt blocks mach-lookup to trustd, the daemon Security.framework's `SecTrustEvaluateWithError` needs for TLS certificate validation. Every tool that validates certs through Security.framework fails with `OSStatus -26276` ("invalid peer certificate") under the sandbox — not Go-specific despite `fj` being Rust, same root cause as the documented gh/gcloud/terraform case. No allowlist knob exists for this (anthropics/claude-code#34876, closed "not planned"); the documented fix is `excludedCommands`. See code.claude.com/docs/en/sandboxing.md#troubleshooting. Docker doesn't compose with the sandbox at all, so it's excluded outright — excluded commands run fully unwrapped, a hole rather than a containment.

Bare command names (`"gh"`, `"fj"`) are *not* respected — matching requires a glob covering the arguments, per the docs' own `"docker *"` example and confirmed by anthropics/claude-code#10524 (bare `"uv"` silently ignored). Bare `"docker"` was never actually verified working; only the rm/write denials were tested there.

rtk twins: the PreToolUse hook rewrites `gh …` to `rtk gh …` (verified for `gh api`, `gh pr view`; not `fj`, not the gh/fj deny targets), and exclusion matching runs on the rewritten command — so `gh *` never matches `rtk gh api …` and `gh` runs fully sandboxed after all, surviving only via the trustd `allowMachLookup` plus the two allowlisted github domains (any `gh` call to another host still dies on the egress block). Same rewrite-defeats-the-rule bug the permission gates hit (see `claude-code.nix`'s `withRtkTwin`); the `rtk gh *`/`rtk fj *` twins restore the intended full bypass. rtk doesn't rewrite `docker` today, but the twin is harmless and future-proofs the same way, since the rewrite inventory is rtk's to change.

## PreToolUse hooks run unsandboxed — the write-escape trap

Verified directly: a hook writing to the denyWrite'd `$HOME` root succeeds while a sandboxed Bash command cannot. That means any file a sandboxed command can write, which a hook later executes or which governs the next session's policy, is an escape hatch:

- `~/.claude/hooks` holds the scripts invoked as `bash ~/.claude/hooks/*.sh` (`claude-code.nix`). Left writable via the `~/.claude` `allowWrite`, a sandboxed or prompt-injected command could overwrite `rtk-hook.sh` and get arbitrary unsandboxed execution on the next Bash call.
- The settings state path is the real file `~/.claude/settings.json` resolves to (`mkOutOfStoreSymlink` into `~/.local/state`, covered by the same `allowWrite`). A sandboxed command running the same jq+mv pattern `rtk-hook.sh` uses could set `permissions.deny = []` or `sandbox.enabled = false` for the next session.

Both are in `denyWrite` as a result. This doesn't hinder rtk itself — it patches `settings.json` from the hook, which runs unsandboxed.

## `allowWrite` needing a matching `allowRead` (2026-08-19, unconfirmed)

Writes to `${home}/.claude` and `${home}/Library/Application Support/rtk` were denied outright despite both being `allowWrite` entries, on Claude Code 2.1.234 — well past the 2.1.224 fix for the trailing-slash bug a previous version of this note blamed (disproven: sandbox-runtime docs describe `allowRead`/`allowWrite` as independent axes, and its mandatory always-denied-write list only covers `.claude/commands/` and `.claude/agents/`, not `.claude` broadly — see anthropic-experimental/sandbox-runtime's README).

Unverified hypothesis, untested against source: every `allowWrite` entry that worked also had `allowRead` covering it; these two didn't. Both are now also in `allowRead` to test that. If writes still fail after this, the hypothesis is wrong and the real cause is still open.

## `claude-yolo`: what it actually trades away

`sandbox.enabled = false` is enough on its own — with the sandbox off, none of `claude-sandbox.nix`'s other `sandbox.*` keys do anything, so this profile doesn't replicate any of them.

`permissions.ask` (git push, `rm -rf`, git reset --hard, ...) is what disappears: `--dangerously-skip-permissions` (bypassPermissions mode) skips every prompt. `permissions.deny` does *not* disappear — deny rules block in every mode including bypassPermissions (confirmed against code.claude.com/docs/en/permission-modes.md), so `gates.nix`'s `denyHard` and `claude-code.nix`'s `credentialDenyRules` still hold. Sandbox and permission-bypass are independent axes (code.claude.com/docs/en/sandboxing.md) — disabling one doesn't disable the other, hence needing both.

The official docs describe bypassPermissions as meant for an isolated container/VM, not a trusted host machine — this runs it on the host anyway, deliberately. With no sandbox and no ask, the global CLAUDE.md hard rules (never push/commit/destroy without approval, never touch main) have no harness backstop left besides `denyHard`/`credentialDenyRules`; they hold only as long as the model chooses to follow them. Use this profile only when that trade-off is wanted for that session, not as a default.

First interactive run shows a one-time disclaimer dialog (accepted state saved to user settings, asked once per machine). Until accepted, a backgrounded run (`--bg`) is refused outright — same gotcha as #93. Accept it via a plain interactive `claude-yolo` invocation before ever trying to background one.
