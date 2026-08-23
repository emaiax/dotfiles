# Claude Code sandbox: investigation notes

Background for the terse pointer comments in `permissions.nix` and `claude-code/default.nix`. Anything here is either a confirmed root cause worth the full trail, or an open question flagged as such. Check the date/status before trusting it.

## `git-credential-osxkeychain` fails with `100001` on `store`

`git push` under the sandbox succeeds, but `git-credential-osxkeychain`'s `store` op fails with `fatal: failed to store: 100001`. The push itself goes through, git just can't cache the credential back afterward. `100001` decodes via `security error 100001` to `errSecErrnoBase(100000)+EPERM`, a raw UNIX errno rather than a Seatbelt denial.

Confirmed by reading anthropic-experimental/sandbox-runtime's `macos-sandbox-utils.ts` (the profile generator this sandbox is built on): the baseline profile already grants unconditional mach-lookup to `com.apple.securityd.xpc` and `com.apple.SecurityServer`, and `allowWrite` for `~/Library/Keychains` already compiles to a clean `file-write*` allow with no unlink/create re-deny catching it, so per the generator's own logic this should already work. Adding `allowWrite` for that path (tried, then reverted) didn't fix it, and a live repro with `log stream` running unsandboxed alongside a sandboxed `store` call showed zero kernel Sandbox deny lines for git/bash/git-credential-osxkeychain in the failure window. If Seatbelt were blocking the syscall, the kernel would log it.

Conclusion: this isn't a rule this profile can express. It points at securityd's own ACL/identity resolution for `SecItemAdd` (new item) under a sandbox-exec-wrapped caller, outside this file's control surface. Accepted as a known limitation: don't re-attempt `allowWrite`/`allowMachLookup` tuning for this without new evidence.

Read access to `~/Library/Keychains` is still required and kept: without it, `git-credential-osxkeychain` can't even reach the keychain database to trigger the normal per-item ACL prompt, and fails silently instead of asking. Read access alone doesn't bypass per-item authorization, macOS still decrypts and gates each item via its own ACL. Same fix as CJHwong/agent-seatbelt's `my.sb`.

## gh/fj/docker escape the sandbox via `excludedCommands`

Seatbelt blocks mach-lookup to trustd, the daemon Security.framework's `SecTrustEvaluateWithError` needs for TLS certificate validation. Every tool that validates certs through Security.framework fails with `OSStatus -26276` ("invalid peer certificate") under the sandbox, not Go-specific despite `fj` being Rust, same root cause as the documented gh/gcloud/terraform case. No allowlist knob exists for this (anthropics/claude-code#34876, closed "not planned"); the documented fix is `excludedCommands`. See code.claude.com/docs/en/sandboxing.md#troubleshooting. Docker doesn't compose with the sandbox at all, so it's excluded outright: excluded commands run fully unwrapped, a hole rather than a containment.

Bare command names (`"gh"`, `"fj"`) are *not* respected: matching requires a glob covering the arguments, per the docs' own `"docker *"` example and confirmed by anthropics/claude-code#10524 (bare `"uv"` silently ignored). Bare `"docker"` was never actually verified working; only the rm/write denials were tested there.

rtk twins: the PreToolUse hook rewrites `gh ...` to `rtk gh ...` (verified for `gh api`, `gh pr view`; not `fj`, not the gh/fj deny targets), and exclusion matching runs on the rewritten command, so `gh *` never matches `rtk gh api ...` and `gh` runs fully sandboxed after all, surviving only via the trustd `allowMachLookup` plus the two allowlisted github domains (any `gh` call to another host still dies on the egress block). Same rewrite-defeats-the-rule bug the permission gates hit (see `permissions.nix`'s `withRtkTwin`); the `rtk gh *`/`rtk fj *` twins restore the intended full bypass. rtk doesn't rewrite `docker` today, but the twin is harmless and future-proofs the same way, since the rewrite inventory is rtk's to change.

## PreToolUse hooks run unsandboxed: the write-escape trap

Verified directly: a hook writing to the denyWrite'd `$HOME` root succeeds while a sandboxed Bash command cannot. That means any file a sandboxed command can write, which a hook later executes or which governs the next session's policy, is an escape hatch:

- The hook scripts themselves. `claude-code/default.nix` invokes them as `bash "<checkout>/modules/user/apps/claudio/hooks/*.sh"`, and `~/.claude/hooks` is an `mkOutOfStoreSymlink` to the same directory. Overwrite `rtk-hook.sh` and you get arbitrary unsandboxed execution on the next Bash call.
- `~/.claude/settings.json`, another `mkOutOfStoreSymlink` into the checkout. Rewriting it sets `permissions.deny = []` or `sandbox.enabled = false` for the next session.

Both were in `denyWrite` until the live-editable rework: they now live under `~/code`, which is `allowWrite` so the agent can work on this repo at all, and `~/.claude` is `allowWrite` so rtk can bootstrap. A `denyWrite` on either path would break the thing it is there to enable, so the escape is currently open and accepted. Anything that closes it has to keep rtk's own patching working, since rtk edits `settings.json` from the hook, which runs unsandboxed.

## `allowWrite` is inert for every path under `$HOME` (2026-08-23, confirmed, upstream bug)

Writes to `${home}/.claude` and `${home}/Library/Application Support/rtk` were denied outright despite both being `allowWrite` entries, on Claude Code 2.1.234. The allowRead-pairing hypothesis this note used to carry is disproven: both paths are in `allowRead` too (see `mkClaudeCodeSandbox` in `permissions.nix`), and writes still fail. So do writes to `${home}/code` itself, the workspaces entry every profile needs to edit this repo at all, confirmed both from the `fs-write-claude-dir` probe case and, separately, live: a Claude Code session with `cwd` inside this checkout got `Operation not permitted` on a plain `mkdir` at the repo root, from inside a `git worktree`, and from `git add`.

Root cause, matched against a public repro, not this closed-source binary: anthropics/claude-code#22947 (closed as stale, not fixed), duplicated by #32757 and #28206. Every user-specified absolute path in `sandbox.filesystem.*` (`allowWrite`, deny rules, `additionalDirectories`) gets incorrectly reprefixed with `~/.claude/` internally before being compiled into the Seatbelt profile, so `/Users/x/code` becomes `/Users/x/.claude/Users/x/code`, a path that does not exist. The grant silently becomes a no-op. This matches the symptom exactly: only `cwd` and temp, which never go through this rewrite, stay writable; every explicit `allowWrite` entry does nothing regardless of what it names.

The deny side of this bug (`denyRead`/`denyWrite` also get mis-prefixed) doesn't matter in practice here: sandbox filesystem writes are deny-by-default, so a mis-prefixed `denyWrite` entry just falls back to the baseline deny it was reinforcing, not a hole.

Tried and ruled out: a `~/`-prefixed path (`"~/code"` instead of `"${home}/code"`, i.e. `/Users/x/code`) goes through a different, documented resolution path (anthropics/claude-code#33090's own closing comment claims exactly this, though that comment is from the reporter, not a maintainer, and contradicts the sandboxing docs' own claim that a plain `/`-prefixed path is already absolute). Tested directly: swapped every `toolchainReadWrite`/`toolchainReadOnly` entry and the sandbox `denyRead`/`denyWrite` base to `~/`-relative form, `fs-write-claude-dir` still came back `BLOCKED`. The `~/` form isn't affected by anything different here, reverted.

Also tried and ruled out: a doubled leading slash (`"//Users/x/code"`), on the theory that the sandbox path compiler might mistakenly reuse the Read/Edit permission layer's `//` = absolute, `/` = project-relative convention instead of its own. Same test, same `toolchainReadWrite`/`toolchainReadOnly` entries prefixed with an extra `/`, `fs-write-claude-dir` still `BLOCKED`. Reverted.

No path-format change on our side can fix this, the bug is in how Claude Code compiles user paths before this repo's settings ever reach it. Worked around instead: `mkClaudeCodeSandbox` sets `sandbox.filesystem.disabled = true` (v2.1.216+), which drops filesystem isolation entirely and makes `allowWrite`/`allowRead`/`denyRead`/`denyWrite` moot, while `sandbox.network` stays enforced (the two are independent layers). `fs-write-claude-dir` and the rest of the `fs-*` suite now expect `EXECUTED`/unrestricted on `claude`, `claudio`, and `claudio-thebot`, same as `claude-yolo` already did.

Trade-off accepted, not mitigated yet: `denyRead` on credential files (`.credentials.json`, `.netrc`, `~/.ssh`, etc.) is part of the filesystem layer too, so it no longer blocks a sandboxed Bash command from reading them, only `permissions.deny`'s `Read`/`Edit` rules still hold, and those don't see Bash. `sandbox.credentials` with `mode: mask` would restore this (on macOS it blocks the read outright, same as `deny`, and survives `filesystem.disabled`), not yet migrated. Revert `disabled = true` and revisit the path-mangling bug directly if upstream fixes #22947.

## `claude-yolo`: what it actually trades away

`sandbox.enabled = false` is enough on its own: with the sandbox off, none of the base profile's other `sandbox.*` keys do anything, so this profile doesn't replicate any of them.

`permissions.ask` (git push, `rm -rf`, git reset --hard, ...) is what disappears: `--dangerously-skip-permissions` (bypassPermissions mode) skips every prompt. `permissions.deny` does *not* disappear: deny rules block in every mode including bypassPermissions (confirmed against code.claude.com/docs/en/permission-modes.md), so `permissions.nix`'s `denyHard` and `credentialDenyRules` still hold. Sandbox and permission-bypass are independent axes (code.claude.com/docs/en/sandboxing.md), disabling one doesn't disable the other, hence needing both.

The official docs describe bypassPermissions as meant for an isolated container/VM, not a trusted host machine. This runs it on the host anyway, deliberately. With no sandbox and no ask, the global CLAUDE.md hard rules (never push/commit/destroy without approval, never touch main) have no harness backstop left besides `denyHard`/`credentialDenyRules`; they hold only as long as the model chooses to follow them. Use this profile only when that trade-off is wanted for that session, not as a default.

First interactive run shows a one-time disclaimer dialog (accepted state saved to user settings, asked once per machine). Until accepted, a backgrounded run (`--bg`) is refused outright, same gotcha as #93. Accept it via a plain interactive `claude-yolo` invocation before ever trying to background one.
