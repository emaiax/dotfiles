# Default sandbox layer for every Claude Code session (see #121). Confines Bash and its children only — Read/Edit/Write go through claude-code.nix's permissions.deny instead (see #126), both built from credential-paths.nix. Profiles layer on top via `--settings`, which merges, so they inherit every deny here. Background/investigation notes: docs/sandbox-notes.md.
#
# Two ways to write a rule that silently does nothing: a trailing slash voids the entry on 2.1.222 (fixed in 2.1.224), and a glob like `$HOME/*` matches nothing and fails open.
{ config, ... }:
let
  home = config.home.homeDirectory;

  # nix breaks under the sandbox without these: the fetcher cache, the state dir, and the daemon socket below.
  nixReads = [
    "${home}/.cache/nix"
    "${home}/.local/state/nix"
  ];

  # Toolchains, not personal data — denying $HOME wholesale takes out npm/node/asdf too.
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

    # Needed just to reach the normal per-item ACL prompt; doesn't bypass it. `git push`'s credential store still fails here with a known, accepted gap — docs/sandbox-notes.md.
    "${home}/Library/Keychains"

    # allowWrite alone wasn't enough for either (docs/sandbox-notes.md); .credentials.json under ~/.claude stays denied regardless — narrower wins for reads, same as writes.
    "${home}/.claude"
    "${home}/Library/Application Support/rtk"
  ];

  # ~/.ssh is denied outright otherwise; commit.gpgSign uses gpg.format = "ssh" (git/git.nix).
  sshSigningReads = [
    "${home}/.ssh/allowed_signers"
    "${home}/.ssh/config"
    "${home}/.ssh/github"
    "${home}/.ssh/github.pub"
    "${home}/.ssh/known_hosts"
  ];

  # Nested inside allowRead above; reads honour narrower-wins but denyWrite beats allowWrite unconditionally, so never pair the two.
  credentialPaths = import ./credential-paths.nix home;
  credentialDenies = credentialPaths.dirs ++ credentialPaths.files;
  credentialBaks = map (p: "${p}.bak") credentialPaths.bakCarveouts;
in
{
  programs.claude-code.settings.sandbox = {
    enabled = true;

    # Without both, the boundary is advisory: Claude may retry a blocked command unsandboxed, or continue if Seatbelt is unavailable.
    allowUnsandboxedCommands = false;
    failIfUnavailable = true;

    autoAllowBashIfSandboxed = true;

    # docker doesn't compose with the sandbox; gh/fj fail cert validation under it (trustd mach-lookup blocked). Excluded commands run fully unwrapped — a hole, not a containment. Each needs a glob (bare names aren't matched) and an `rtk `-prefixed twin, since the PreToolUse hook rewrites gh/fj commands before this matches against them. Full background: docs/sandbox-notes.md.
    excludedCommands = [
      "docker *"
      "rtk docker *"
      "gh *"
      "rtk gh *"
      "fj *"
      "rtk fj *"
    ];

    # Without this, `open -a <App>` fails with kLSUnknownErr: launching another app's process needs a mach-lookup to RunningBoard/launchservicesd that the sandbox blocks.
    allowAppleEvents = true;

    network = {
      # Without this every nix subcommand fails to reach its daemon.
      allowUnixSockets = [ "/nix/var/nix/daemon-socket/socket" ];

      # gh/terraform/kubectl validate TLS via Security.framework → trustd, which Seatbelt blocks by default (`x509: OSStatus -26276`, even for a valid cert; curl/git/Node verify in-process and are unaffected). anthropics/claude-code#26466.
      allowMachLookup = [ "com.apple.trustd.agent" ];

      # github.com covers git-over-https; api.github.com is the gh CLI's separate REST/GraphQL host — without it gh dies on the egress block before reaching gates.nix's own rules. Both public, so plain literals; the private homelab domain is patched in at runtime as a wildcard instead — claude-hooks/homelab-network-hook.sh.
      allowedDomains = [
        "github.com"
        "api.github.com"
      ];
    };

    filesystem = {
      # Reads are allow-everything by default upstream; deny $HOME, allow back the toolchain.
      # credentialBaks: same reasoning as the denyWrite carve-out below.
      denyRead = [ home ] ++ credentialDenies ++ credentialBaks;
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

        # rtk's global init writes RTK.md and its filters template into these; denyWrite below still keeps .credentials.json out of reach.
        "${home}/.claude"
        "${home}/Library/Application Support/rtk"
      ];

      # bakCarveouts/credentialBaks: the credentialDenies entries nested under an allowWrite path need denying again here, plus their .bak sibling (see #126). ~/.claude/hooks and the settings state path close a same-session escape — PreToolUse hooks run unsandboxed, so a sandboxed command could otherwise overwrite rtk-hook.sh or flip permissions.deny/sandbox.enabled for the next session. Full trail: docs/sandbox-notes.md.
      denyWrite =
        credentialPaths.bakCarveouts
        ++ credentialBaks
        ++ [
          "${home}/.claude/hooks"
          "${home}/.local/state/claude-code/settings.json"
        ];
    };
  };
}
