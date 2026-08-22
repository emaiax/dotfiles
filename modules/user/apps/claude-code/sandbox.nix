# Default sandbox layer for every Claude Code session (see #121). Confines Bash and its children only.
# Read/Edit/Write go through claude-code.nix's permissions.deny instead (see #126), both built from
# claudio/permissions.nix. Profiles layer on top via `--settings`, which merges, so they inherit every deny here.
# Background/investigation notes: docs/sandbox-notes.md.
#
# Two ways to write a rule that silently does nothing: a trailing slash voids the entry on 2.1.222 (fixed in
# 2.1.224), and a glob like `$HOME/*` matches nothing and fails open.
{ config, lib, ... }:
let
  home = config.home.homeDirectory;

  # Shared with claude-code.nix and opencode.nix.
  perms = import ../claudio/permissions.nix { inherit home lib; };
  inherit (perms)
    nixReads
    toolchainReads
    sshSigningReads
    excludedCommands
    allowedDomains
    ;

  # Nested inside allowRead above; reads honour narrower-wins but denyWrite beats allowWrite unconditionally, so
  # never pair the two.
  credentialDenies = perms.dirs ++ perms.files;
  credentialBaks = map (p: "${p}.bak") perms.bakCarveouts;
in
{
  programs.claude-code.settings.sandbox = {
    enabled = true;

    # Without both, the boundary is advisory: Claude may retry a blocked command unsandboxed, or continue if
    # Seatbelt is unavailable.
    allowUnsandboxedCommands = false;
    failIfUnavailable = true;

    autoAllowBashIfSandboxed = true;

    # docker/gh/fj policy: permissions.nix's excludedCommands.
    inherit excludedCommands;

    # Without this, `open -a <App>` fails with kLSUnknownErr: launching another app's process needs a mach-lookup
    # to RunningBoard/launchservicesd that the sandbox blocks.
    allowAppleEvents = true;

    network = {
      # Without this every nix subcommand fails to reach its daemon.
      allowUnixSockets = [ "/nix/var/nix/daemon-socket/socket" ];

      # gh/terraform/kubectl validate TLS via Security.framework → trustd, which Seatbelt blocks by default
      # (`x509: OSStatus -26276`, even for a valid cert; curl/git/Node verify in-process and are unaffected).
      # anthropics/claude-code#26466.
      allowMachLookup = [ "com.apple.trustd.agent" ];

      # github.com/api.github.com policy: permissions.nix's allowedDomains.
      inherit allowedDomains;
    };

    filesystem = {
      # Reads are allow-everything by default upstream; deny $HOME, allow back the toolchain.
      # credentialBaks: same reasoning as the denyWrite carve-out below.
      denyRead = [ home ] ++ credentialDenies ++ credentialBaks;
      allowRead = toolchainReads ++ nixReads ++ sshSigningReads;

      # Writes are already deny-by-default, and cwd is writable implicitly. Package managers need to write where
      # they install.
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

        # rtk's global init writes RTK.md and its filters template into these; denyWrite below still keeps
        # .credentials.json out of reach.
        "${home}/.claude"
        "${home}/Library/Application Support/rtk"
      ];

      # bakCarveouts/credentialBaks: the credentialDenies entries nested under an allowWrite path need denying
      # again here, plus their .bak sibling (see #126). ~/.claude/hooks and the settings state path close a
      # same-session escape: PreToolUse hooks run unsandboxed, so a sandboxed command could otherwise overwrite
      # rtk-hook.sh or flip permissions.deny/sandbox.enabled for the next session. Full trail: docs/sandbox-notes.md.
      denyWrite =
        perms.bakCarveouts
        ++ credentialBaks
        ++ [
          "${home}/.claude/hooks"
          "${home}/.local/state/claude-code/settings.json"
        ];
    };
  };
}
