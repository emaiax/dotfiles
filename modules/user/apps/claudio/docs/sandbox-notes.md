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

## Bare `claude` has zero permissions of its own (2026-09-10)

Until 2026-09-10, `claude-code/default.nix` wired the shared `policy` into the base `programs.claude-code.settings.permissions` for every session on the machine, profile wrapper or not: `ask` on `git push`/`rm -rf`/etc., unconditional credential-file `deny`, `hardDeny = false`. That forced every plain `claude` invocation through the same `ask`-on-`git push` friction meant for the specialized profiles, verified live to be actual friction (a real session got prompted for a push it had no way to route around).

The base now defines no `permissions` key at all. Each specialized profile opts in explicitly via `permissions.nix`'s `claudeCode` bundles instead: `claudio.nix` uses `claudeCode.user` (the full `mkClaudeCodePermissions` bundle, `hardDeny = true`), `claudio-thebot.nix` uses `claudeCode.yolo` (the literal empty object, zero ask/deny/allow, see its own section below), and `claude-yolo.nix` uses `claudeCode.credentialDenyOnly` (just the credential-file `deny` rules, opted back in explicitly since the base no longer hands them out for free).

A bare, unwrapped `claude` invocation (no `--settings` file of its own) now inherits none of this: no `ask`, no `deny`, not even the credential-file rules. `permissions.deny` is still a monotonic union across every settings source Claude Code loads when one *is* declared (nothing can remove a deny that a lower-precedence file declares, not even `--dangerously-skip-permissions`, confirmed against code.claude.com/docs/en/settings.md and permission-modes.md); the change here is that no source declares any deny for a bare session any more, not that the union stopped working. Accepted trade-off, not a bug: removing the bare binary from PATH was considered and rejected as more invasive than it's worth (`programs.claude-code.package = null` collides with the package's own `bin/claude` output unless the module is reworked further).

## `claude-yolo`: what it actually trades away

`sandbox.enabled = false` is enough on its own: with the sandbox off, none of the base profile's other `sandbox.*` keys do anything, so this profile doesn't replicate any of them.

`permissions.ask` (git push, `rm -rf`, git reset --hard, ...) is what disappears: `--dangerously-skip-permissions` (bypassPermissions mode) skips every prompt, and this profile declares no `ask` of its own either. `permissions.deny` does *not* disappear when it's actually declared: deny rules block in every mode including bypassPermissions (confirmed against code.claude.com/docs/en/permission-modes.md). For `claude-yolo` specifically, that's `permissions.nix`'s `claudeCode.credentialDenyOnly` bundle (2026-09-10): just the credential-file rules, opted into explicitly now that the base no longer hands them out unconditionally (see the section above). Sandbox and permission-bypass are independent axes (code.claude.com/docs/en/sandboxing.md), disabling one doesn't disable the other, hence needing both.

`claudio-thebot` (the homelab publishing agent, consolidated 2026-09-10) goes further: `claudeCode.yolo` is the literal empty object, so it doesn't even keep the credential-file deny `claude-yolo` opts back into. That's a deliberate, narrower choice for that one profile (see its own file's header comment), not the default for every yolo-style profile.

The official docs describe bypassPermissions as meant for an isolated container/VM, not a trusted host machine. This runs it on the host anyway, deliberately. With no sandbox, no ask, and no irreversible-command tier, the global CLAUDE.md hard rules (never push/commit/destroy without approval, never touch main) have no harness backstop left besides `credentialDenyOnly`'s credential-file rules; everything else, including merging and publishing releases, holds only as long as the model chooses to follow the project's own documented approval gate (e.g. dudumox's `docs/guidelines/how-to-work.md` "What authorizes a merge"). Use this profile only when that trade-off is wanted for that session, not as a default.

First interactive run shows a one-time disclaimer dialog (accepted state saved to user settings, asked once per machine). Until accepted, a backgrounded run (`--bg`) is refused outright. Accept it via a plain interactive `claude-yolo` invocation before ever trying to background one.

## Hook command wiring: live checkout, not `$HOME/.claude`

The PreToolUse hook in `claude-code/default.nix` runs `bash "<checkout>/modules/user/apps/claudio/hooks/rtk-hook.sh"` against the live checkout path, not `$HOME/.claude/hooks/rtk-hook.sh`, so it doesn't depend on the `~/.claude/hooks` symlink (see the write-escape section above) landing correctly first. It runs via `bash "path"` rather than a direct exec because the hook scripts are tracked `100644` in git: a non-executable hook fails silently instead of erroring, and wrapping in `bash` sidesteps the executable bit entirely.

## `permissions.nix`: policy is data, renderers translate it per consumer

`policy` (commands, credentials, filesystem, network) is the single source of truth, consumed by three renderers: `mkClaudeCodePermissions`/`mkClaudeCodeSandbox` for Claude Code's native settings shape, and `mkOpencodePermissions` for OpenCode's unrelated schema (no equivalent tiering there). A profile opts in explicitly: `claudeCode.user` (claudio.nix, the full ask/deny bundle, `hardDeny` gates the irreversible-command tier), `claudeCode.yolo` (claudio-thebot.nix, the literal empty object), or `claudeCode.credentialDenyOnly` (claudio-yolo.nix, just the credential-file deny rules). `claudeCode.sandbox` is the one bundle every profile gets regardless, wired in from `claude-code/default.nix` directly.

Command tiers, in `policy.commands`: `allow` (ssh's `ProxyCommand` case, needs an explicit allow to run at all), `ask` (destructive but undoable: git push, reset --hard, rm -rf, ...), `denyHard` (irreversible: gh/fj merge and release, opt-in via `hardDeny` since deny unions across every settings source and a `--settings` file can't remove one), `denySoft` (reversible, so these only render as prose in `autoMode.soft_deny` rather than a hard `deny`, and only for Claude Code: OpenCode has no equivalent tier, `opencode.permission.bash` is a flat allow), and `bypassSandboxSeatbelt` (docker/gh/fj/ssh, excluded from the sandbox entirely, see "gh/fj/docker escape the sandbox" above).

## Credential deny is two independent layers

`policy.filesystem.credentials` feeds two unrelated deny mechanisms: `claudeCodeCredentialDenyRules` produces `Read`/`Edit` tool-level deny rules that reach the native tools directly (the sandbox never sees them), and `mkClaudeCodeSandbox`'s `denyRead`/`denyWrite` confines the sandboxed Bash subprocess instead. `Write(path)` tool rules are silently never checked by Claude Code, so `Edit` stands in for `Write` too. OpenCode has no path-based deny mechanism of its own yet, so only Claude Code's two halves read this policy today.

A sibling `.bak` file (home-manager's `backupFileExtension = "bak"`) could ride the same allow grant back in as the file it backs up, so `credentialBaks` denies every credential file's `.bak` too, not just ones already nested under a denied directory.

## `toolchainReadWrite` is one list, not two

Toolchain paths (not personal data: denying `$HOME` wholesale would take out npm/node/asdf too) need both read and write access, so `mkClaudeCodeSandbox`'s `allowRead` and `allowWrite` both draw from `policy.filesystem.toolchainReadWrite` instead of each retyping the list. `allowWrite` drifted out of sync with `allowRead` before this was unified.

## SSH agent signing keys stay readable despite the `~/.ssh` deny

`~/.ssh` itself is denied via `policy.filesystem.credentials.dirs`, but commit signing through the ssh agent needs to read the public keys and config it signs with. The agent socket is ephemeral, so it can't be `allowWrite`, only `allowRead` on `~/.ssh/*.pub`, `allowed_signers`, `config`, and `known_hosts`.

This resolves at all because Seatbelt is last-match-wins, and Claude Code's own sandbox profile generator re-emits `allowRead` entries after the deny they're nested under (anthropic-experimental/sandbox-runtime's `macos-sandbox-utils.ts`: "denyOnly: deny reads from these paths ... allowWithinDeny: re-allow reads within denied regions ... allowWithinDeny takes precedence over denyOnly"), so these four paths resolve readable despite the broader `~/.ssh` deny.

## `autoMode`: prose a model judges, not mechanical enforcement

`autoMode` only applies while a session is in auto mode, and is prose a model interprets, not permission-rule enforcement: wording changes the outcome. Anything that must hold regardless of mode belongs in `permissions` instead. A profile's `autoMode.allow` can override a `soft_deny` entry from the base, the only sanctioned way to loosen anything inherited here.

`environment` deliberately carries no hostnames, org names, or topology: this repo mirrors publicly, and the built-in defaults already trust the working repo's own remotes; repo-specific context belongs in that repo's own CLAUDE.md, which the classifier also reads.

`soft_deny` entries are phrased as a category, never as an absolute: "under any circumstances" would make an entry unoverridable, and claudio-thebot needs to override the forge-activity one specifically. The wording also never states that stating intent clears the rule, since spelling that out would itself read as permission to ignore it.

## `claudio-thebot`'s `--add-dir`/`--plugin-dir`/`--append-system-prompt-file` wiring

`claudio-thebot` can be invoked from anywhere, not just from inside the target repos, and Read/Edit/Write only see the launch cwd by default, so it needs `--add-dir` for claudio-core. `--plugin-dir` loads claudio-core's own `skills/` on top of the operator's base CLAUDIO persona, namespaced as `claudio-core:<skill-name>` (claudio-core carries a `.claude-plugin/plugin.json` manifest for exactly this).

`--add-dir` does not auto-load a CLAUDE.md from the directories it grants, despite what `claude --bare --help` implies: verified empirically, a live session had no knowledge of claudio-core's AGENTS.md content until `--append-system-prompt-file` was added. That flag is the one that actually merges it in.

This profile is yolo-only since the 2026-09-10 consolidation: there used to be a second, gated variant plus a separate `claudio-thebot-yolo` binary, both gone. This is the homelab-scoped AFK publishing agent, not a profile meant to still ask anything, see AGENTS.md's Autonomy & Approval section.
