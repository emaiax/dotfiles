# Default sandbox layer for every Claude Code session (see #121).
#
# Confines Bash and its children only. Read/Edit/Write go through the permission system instead — that's the other half of the credential policy, in claude-code.nix's permissions.deny, both halves built from credential-paths.nix so they can't drift apart (see #126). Profiles layer on top via `--settings`, which merges, so they inherit every deny here.
#
# Two ways to write a rule that silently does nothing: a trailing slash voids the entry on 2.1.222 (fixed in 2.1.224), and a glob like `$HOME/*` matches nothing and fails open.
#
# 2026-08-19: writes to ${home}/.claude and ${home}/Library/Application Support/rtk were denied outright despite both being allowWrite entries, on 2.1.234 — well past the 2.1.224 a previous note here blamed (that theory was disproven; sandbox-runtime docs describe allowRead/allowWrite as independent axes, and its mandatory always-denied-write list only covers .claude/commands/ and .claude/agents/, not .claude broadly — https://github.com/anthropic-experimental/sandbox-runtime/blob/main/README.md). Unverified hypothesis, untested against source: every allowWrite entry that worked also had allowRead covering it; these two didn't. Both are now also in allowRead below to test that. If writes still fail after this, the hypothesis is wrong and the real cause is still open.
{ config, ... }:
let
  home = config.home.homeDirectory;

  # nix breaks three separate ways under the sandbox: the fetcher cache, the state dir, and the daemon socket below.
  nixReads = [
    "${home}/.cache/nix"
    "${home}/.local/state/nix"
  ];

  # Toolchains live scattered across top-level dotfiles, so denying $HOME wholesale takes out npm, node and every asdf-managed runtime. Deny personal data, not the toolchain.
  toolchainReads = [
    "${home}/code"
    "${home}/.cache"
    "${home}/.config"
    "${home}/.local"
    "${home}/Library/Caches" # treefmt, which `nix fmt` runs, caches here rather than under XDG
    "${home}/.gitconfig"

    # The Bash tool runs commands through the login shell.
    "${home}/.zshrc"
    "${home}/.zshenv"

    "${home}/.asdf"
    "${home}/.bun"
    "${home}/.npm"
    "${home}/.gem"
    "${home}/.bundle"
    "${home}/.mix"
    "${home}/.hex"
    "${home}/go"
    "${home}/.terraform.d"
    "${home}/.nix-profile"
    "${home}/.nix-defexpr"

    # git-credential-osxkeychain (and other Security.framework keychain consumers) needs
    # to read the keychain database to even reach the normal per-item ACL prompt — without
    # this the read is denied outright and the helper fails silently instead of asking.
    # Read access alone doesn't bypass per-item authorization; macOS still decrypts and
    # gates each item via its own ACL. Same fix as CJHwong/agent-seatbelt's my.sb.
    #
    # Known non-blocking gap: `git push` under this sandbox still ends with `fatal:
    # failed to store: 100001` from git-credential-osxkeychain's `store` op (push itself
    # succeeds; git just can't cache the credential back). 100001 decodes via `security
    # error 100001` to errSecErrnoBase(100000)+EPERM — a raw UNIX errno, not a Seatbelt
    # denial. Confirmed by reading anthropic-experimental/sandbox-runtime's
    # macos-sandbox-utils.ts (the profile generator this sandbox is built on): the
    # baseline profile already grants unconditional mach-lookup to
    # com.apple.securityd.xpc and com.apple.SecurityServer, and allowWrite here already
    # compiles to a clean file-write* allow with no unlink/create re-deny catching it —
    # so per the generator's own logic, this should already work. Adding allowWrite for
    # this path (tried, then reverted) did not fix it, and a live repro with `log stream`
    # running unsandboxed alongside a sandboxed `store` call showed zero kernel Sandbox
    # deny lines for git/bash/git-credential-osxkeychain in the failure window — if
    # Seatbelt were blocking the syscall, the kernel would log it. The failure isn't a
    # rule this profile can express; it points at securityd's own ACL/identity
    # resolution for SecItemAdd (new item) under a sandbox-exec-wrapped caller, outside
    # this file's control surface. Accepted as a known limitation; do not re-attempt
    # allowWrite/allowMachLookup tuning for this without new evidence.
    "${home}/Library/Keychains"

    # Whole directory, not just RTK.md: allowWrite alone wasn't enough to make ~/.claude
    # actually writable (see the 2026-08-19 note above), so read access is granted too.
    # .credentials.json stays denied regardless — narrower wins for reads, same as writes.
    "${home}/.claude"

    # Same story as ~/.claude above: allowWrite alone didn't make this writable.
    "${home}/Library/Application Support/rtk"
  ];

  # `commit.gpgSign = true` with `gpg.format = "ssh"` (modules/user/git/git.nix), so denying ~/.ssh outright breaks every commit. The other four private keys stay denied.
  sshSigningReads = [
    "${home}/.ssh/allowed_signers"
    "${home}/.ssh/config"
    "${home}/.ssh/github"
    "${home}/.ssh/github.pub"
    "${home}/.ssh/known_hosts"
  ];

  # Nested inside the allowRead trees above, which works because reads honour narrower-wins. Writes do not: denyWrite beats allowWrite unconditionally, so never pair the two.
  credentialPaths = import ./credential-paths.nix home;
  credentialDenies = credentialPaths.dirs ++ credentialPaths.files;
in
{
  programs.claude-code.settings.sandbox = {
    enabled = true;

    # Without both, the boundary is advisory: Claude may retry a blocked command unsandboxed, or continue if Seatbelt is unavailable.
    allowUnsandboxedCommands = false;
    failIfUnavailable = true;

    autoAllowBashIfSandboxed = true;

    # Docker does not compose with the sandbox. Excluded commands run entirely unwrapped, so this is a hole rather than a containment.
    #
    # gh and fj: Seatbelt blocks mach-lookup to trustd, the daemon Security.framework's
    # SecTrustEvaluateWithError needs for TLS certificate validation. Every tool that
    # validates certs through Security.framework fails with OSStatus -26276 ("invalid
    # peer certificate") under the sandbox — not Go-specific despite fj being Rust, same
    # root cause as the documented gh/gcloud/terraform case. No allowlist knob exists for
    # this (anthropics/claude-code#34876, closed "not planned"); the documented fix is
    # excludedCommands. See code.claude.com/docs/en/sandboxing.md#troubleshooting.
    #
    # Bare command names ("gh", "fj") are NOT respected — matching requires a glob
    # covering the arguments, per the docs' own "docker *" example and confirmed by
    # anthropics/claude-code#10524 (bare "uv" silently ignored). Bare "docker" above
    # was never actually verified working; only rm/write denials were tested.
    excludedCommands = [
      "docker *"
      "gh *"
      "fj *"
    ];

    # Without this, `open -a <App>` fails with kLSUnknownErr ("couldn't communicate
    # with a helper application"): the sandbox blocks the mach-lookup to
    # RunningBoard/launchservicesd that launching another app's process requires.
    allowAppleEvents = true;

    network = {
      # Without this every nix subcommand fails to reach its daemon.
      allowUnixSockets = [ "/nix/var/nix/daemon-socket/socket" ];

      # Go binaries (gh, terraform, kubectl) validate TLS certs via macOS's
      # Security.framework, which delegates to trustd over a Mach-service lookup
      # Seatbelt denies by default, surfacing as `x509: OSStatus -26276` even for
      # a valid cert (curl/git/Node verify in-process and are unaffected). This
      # re-grants just that one lookup rather than excluding the whole command
      # from the sandbox. See anthropics/claude-code#26466 (comments from
      # pradeep-mj and cdunkelb).
      allowMachLookup = [ "com.apple.trustd.agent" ];

      # github.com covers plain git-over-https; the gh CLI talks to a separate host for
      # its REST/GraphQL API, and without it every gh command that isn't a hard deny still
      # dies on a network-outbound block instead of reaching the permission gates in
      # gates.nix (ask/soft_deny/hard_deny) that were meant to be what actually governs it.
      # Both are public, so they're plain literals here. The forgejo host is private (this
      # repo mirrors publicly) and gets patched into settings.json at runtime instead —
      # see claude-hooks/rtk-hook.sh.
      allowedDomains = [
        "github.com"
        "api.github.com"
      ];
    };

    filesystem = {
      # Reads are allow-everything by default upstream. Denying $HOME and allowing back the toolchain recovers most of what agent-jail gave.
      # .credentials.json.bak: same reasoning as the denyWrite carve-out below — the only
      # credentialDenies entry nested under an allowRead path, so the only one a sibling .bak
      # could ride the reallow back in on.
      denyRead = [ home ] ++ credentialDenies ++ [ "${home}/.claude/.credentials.json.bak" ];
      allowRead = toolchainReads ++ nixReads ++ sshSigningReads;

      # Writes are already deny-by-default, and cwd is writable implicitly. Package managers need to write where they install.
      allowWrite = [
        "${home}/code"
        "${home}/.cache"
        "${home}/.local/state"
        "${home}/Library/Caches"
        "${home}/.asdf"
        "${home}/.bun"
        "${home}/.npm"
        "${home}/.gem"
        "${home}/go"

        # rtk's global init (`rtk init -g`) writes RTK.md here. denyWrite below keeps
        # the credential file out of reach even though it's nested under this entry.
        "${home}/.claude"

        # rtk's global init also writes its filters template here, outside ~/.claude.
        "${home}/Library/Application Support/rtk"
      ];

      # denyWrite beats allowWrite unconditionally (see credentialDenies above) — this
      # is that same carve-out for writes, needed now that ~/.claude is allowWrite. Only
      # .credentials.json needs this: it's the only credentialDenies entry nested under an
      # allowWrite path, so it's the only one a sibling .bak (e.g. home-manager's
      # backupFileExtension) could smuggle onto the same allowWrite grant (see #126).
      denyWrite = [
        "${home}/.claude/.credentials.json"
        "${home}/.claude/.credentials.json.bak"
      ];
    };
  };
}
