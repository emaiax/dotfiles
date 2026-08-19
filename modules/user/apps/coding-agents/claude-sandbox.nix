# Default sandbox layer for every Claude Code session (see #121).
#
# Confines Bash and its children only. Read/Edit/Write go through the permission system, so a path policy covering both has to be written twice; this is the Bash half. Profiles layer on top via `--settings`, which merges, so they inherit every deny here.
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
  credentialDenies = [
    "${home}/.aws"
    "${home}/.claude/.credentials.json"
    "${home}/.config/1Password"
    "${home}/.config/sops"

    # Deny the credential file, never the config directory around it: denying ~/.config/gh stopped gh starting at all, and ~/.config/opencode holds only config while opencode keeps its tokens under ~/.local/share.
    "${home}/.local/share/opencode/auth.json"
    "${home}/.local/share/opencode/mcp-auth.json"
    "${home}/.docker/config.json"
    "${home}/.gnupg"
    "${home}/.netrc"
    "${home}/.npmrc"
  ];
in
{
  programs.claude-code.settings.sandbox = {
    enabled = true;

    # Without both, the boundary is advisory: Claude may retry a blocked command unsandboxed, or continue if Seatbelt is unavailable.
    allowUnsandboxedCommands = false;
    failIfUnavailable = true;

    autoAllowBashIfSandboxed = true;

    # Docker does not compose with the sandbox. Excluded commands run entirely unwrapped, so this is a hole rather than a containment.
    excludedCommands = [ "docker" ];

    # Without this, `open -a <App>` fails with kLSUnknownErr ("couldn't communicate
    # with a helper application"): the sandbox blocks the mach-lookup to
    # RunningBoard/launchservicesd that launching another app's process requires.
    allowAppleEvents = true;

    network = {
      # Without this every nix subcommand fails to reach its daemon.
      allowUnixSockets = [ "/nix/var/nix/daemon-socket/socket" ];

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
      denyRead = [ home ] ++ credentialDenies;
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
      # is that same carve-out for writes, needed now that ~/.claude is allowWrite.
      denyWrite = [
        "${home}/.claude/.credentials.json"
      ];
    };
  };
}
