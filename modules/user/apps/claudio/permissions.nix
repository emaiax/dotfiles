# Permissions for commands, filesystem paths, and network domains policy shared across every coding agent and profile in this repo.
# These are the loosest any profile will ever be, since they land in the user layer and a higher-precedence layer cannot loosen them.
#
# Also renders that raw policy into each backend's native settings shape (claudeCodeCredentialDenyRules,
# opencodeBashRules), so claude-code.nix and opencode/default.nix don't each carry their own copy of the same translation.
#
# Each field below is tagged with who actually reads it: claude-code (native Read/Edit/Bash permissions),
# claude-code.sandbox (the Seatbelt boundary specifically), opencode, or more than one.
{ home, lib }:
let
  raw = {
    # tags: unused, not wired into either backend yet
    allow = [
      "git commit" # local and reversible
    ];

    # tags: claude-code, opencode
    ask = [
      "git push"

      # Destructive and hard to undo
      "git reset --hard"
      "git checkout --"
      "git restore"
      "git clean"
      "git rebase"
      "rm -rf"
    ];

    # Irreversible, so these go to `permissions.deny` where nothing overrides them.
    # tags: claude-code, opencode
    denyHard = [
      "gh pr merge"
      "gh release"
      "fj pr merge"
      "fj release"
    ];

    # Reversible, so these become prose in auto-mode.nix's soft_deny, which claudio-thebot can carve an exception out
    # of. OpenCode has no classifier and renders them as plain denies instead.
    # tags: opencode (claude-code's soft tier is separately hand-written prose in auto-mode.nix, not read from here)
    denySoft = [
      "gh pr create"
      "gh pr ready"
      "gh pr review"
      "gh pr comment"
      "gh pr close"
      "gh issue create"
      "gh issue edit"
      "gh issue comment"

      "fj pr create"
      "fj pr review"
      "fj pr close"
      "fj pr comment"
      "fj issue create"
      "fj issue edit"
      "fj issue comment"
    ];

    # Matched literally rather than as a prefix.
    # tags: claude-code, opencode
    askExact = [ "git checkout ." ];

    # No allowlist: `ls` and `cat` are aliases resolving to nix store paths that no name-based rule matches, so an
    # allowlist blocks them however it is written.

    # derived globs that would widen the rule
    # tags: opencode
    opencodePatterns = {
      "git checkout --" = "git checkout -- *"; # avoids swallowing `--track` and `--force`
    };

    ## Filesystem paths that must stay out of every agent's reach, no matter which tool asks for them. sandbox.nix
    ## denies these to the sandboxed Bash subprocess via sandbox.filesystem.denyRead/denyWrite, and claude-code.nix
    ## denies them to the native Read/Edit tools via permissions.deny, which the sandbox never sees.

    # Directories: Read/Edit deny rules need a /** suffix to reach files nested inside.
    # tags: claude-code, claude-code.sandbox
    dirs = [
      "${home}/.aws"
      "${home}/.config/1Password"
      "${home}/.config/sops"
      "${home}/.gnupg"
    ];

    # Single files.
    # tags: claude-code, claude-code.sandbox
    files = [
      "${home}/.claude/.credentials.json"

      # Deny the credential file, never the config directory around it: denying ~/.config/gh stopped gh starting at
      # all, and ~/.config/opencode holds only config while opencode keeps its tokens under ~/.local/share.
      "${home}/.local/share/opencode/auth.json"
      "${home}/.local/share/opencode/mcp-auth.json"
      "${home}/.docker/config.json"
      "${home}/.netrc"
      "${home}/.npmrc"
    ];

    # Files above nested inside an allowRead/allowWrite tree by name, not a wholesale-denied directory, so a sibling
    # `.bak` (backupFileExtension = "bak") could ride the same grant back in and needs its own carve-out. Only
    # .credentials.json qualifies today.
    # tags: claude-code, claude-code.sandbox
    bakCarveouts = [
      "${home}/.claude/.credentials.json"
    ];

    ## Sandbox policy for Claude Code's Seatbelt boundary: filesystem paths every profile needs read access to, plus
    ## the commands and domains that sit outside it. Only claude-code/sandbox.nix consumes this half, OpenCode has no
    ## sandbox mechanism.

    # nix breaks under the sandbox without these: the fetcher cache, the state dir, and the daemon socket (wired
    # separately in sandbox.nix).
    # tags: claude-code.sandbox
    nixReads = [
      "${home}/.cache/nix"
      "${home}/.local/state/nix"
    ];

    # Toolchains, not personal data: denying $HOME wholesale takes out npm/node/asdf too.
    # tags: claude-code.sandbox
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

      # Needed just to reach the normal per-item ACL prompt; doesn't bypass it. `git push`'s credential store still
      # fails here with a known, accepted gap (docs/sandbox-notes.md).
      "${home}/Library/Keychains"

      # allowWrite alone wasn't enough for either (docs/sandbox-notes.md); .credentials.json under ~/.claude stays
      # denied regardless: narrower wins for reads, same as writes.
      "${home}/.claude"
      "${home}/Library/Application Support/rtk"
    ];

    # ~/.ssh is denied outright otherwise; commit.gpgSign uses gpg.format = "ssh" (git/git.nix).
    # tags: claude-code.sandbox
    sshSigningReads = [
      "${home}/.ssh/allowed_signers"
      "${home}/.ssh/config"
      "${home}/.ssh/github"
      "${home}/.ssh/github.pub"
      "${home}/.ssh/known_hosts"
    ];

    # docker doesn't compose with the sandbox; gh/fj fail cert validation under it (trustd mach-lookup blocked).
    # Excluded commands run fully unwrapped: a hole, not a containment. Each needs a glob (bare names aren't matched)
    # and an `rtk `-prefixed twin, since the PreToolUse hook rewrites gh/fj commands before this matches against
    # them. Full background: docs/sandbox-notes.md.
    # tags: claude-code.sandbox
    excludedCommands = [
      "docker *"
      "rtk docker *"
      "gh *"
      "rtk gh *"
      "fj *"
      "rtk fj *"
    ];

    # homelab domain is patched in at runtime in hooks/homelab-network-hook.sh
    # tags: claude-code.sandbox
    allowedDomains = [
      "github.com" # git-over-https
      "api.github.com" # gh api
    ];

    # Not policy: plain path constants that claude-code.nix and sandbox.nix both need to agree on. They're
    # sibling files, neither imports the other, so without a shared spot they silently drift apart (see #126).
    # settingsPath backs sandbox.nix's denyWrite: PreToolUse hooks run unsandboxed, so a sandboxed command could
    # otherwise overwrite a hook script or flip permissions.deny/sandbox.enabled for the next session.
    # tags: claude-code.sandbox
    sandbox = {
      settingsPath = "${home}/code/dotfiles/modules/user/apps/claudio/claude-code/settings.json";
      hooksPath = "${home}/.claude/hooks";
    };
  };

  # Claude Code's native Read/Edit tools deny credentials by path (see #126); the sandbox denies the same set to
  # the Bash subprocess instead, straight off raw.dirs/raw.files in sandbox.nix.
  absRule = path: lib.removePrefix "/" path;
  fileDenyRules = path: [
    "Read(//${absRule path})"
    "Edit(//${absRule path})"
  ];
  dirDenyRules = path: [
    "Read(//${absRule path}/**)"
    "Edit(//${absRule path}/**)"
  ];
  # tags: claude-code
  claudeCodeCredentialDenyRules =
    lib.concatMap fileDenyRules (raw.files ++ map (p: "${p}.bak") raw.bakCarveouts)
    ++ lib.concatMap dirDenyRules raw.dirs;

  # OpenCode has no ask/deny split by classifier, so denyHard and denySoft both render as plain denies here.
  # last-matching-rule-wins, evaluated in *declaration* order: Nix attrsets don't preserve that order when
  # serialized to JSON (keys come out alphabetical), so every rule after the "*" catch-all has to be pinned with
  # entryAfter or it can silently reorder ahead of it.
  opencodePrefixRule = action: cmd: {
    name = raw.opencodePatterns.${cmd} or "${cmd}*";
    value = lib.hm.dag.entryAfter [ "*" ] action;
  };
  opencodeExactRule = action: cmd: {
    name = cmd;
    value = lib.hm.dag.entryAfter [ "*" ] action;
  };
  # tags: opencode
  opencodeBashRules = builtins.listToAttrs (
    map (opencodePrefixRule "ask") raw.ask
    ++ map (opencodePrefixRule "deny") (raw.denyHard ++ raw.denySoft)
    ++ map (opencodeExactRule "ask") raw.askExact
  );

  # Nested inside allowRead below; reads honour narrower-wins but denyWrite beats allowWrite unconditionally, so
  # never pair the two.
  credentialDenies = raw.dirs ++ raw.files;
  credentialBaks = map (p: "${p}.bak") raw.bakCarveouts;

  # Full programs.claude-code.settings.sandbox.filesystem block. sandbox.nix just wires this in, it carries no
  # policy of its own beyond the Seatbelt toggles that aren't data (enabled, allowUnsandboxedCommands, and so on).
  # tags: claude-code.sandbox
  claudeCodeSandboxFilesystem = {
    # Reads are allow-everything by default upstream; deny $HOME, allow back the toolchain.
    # credentialBaks: same reasoning as the denyWrite carve-out below.
    denyRead = [ home ] ++ credentialDenies ++ credentialBaks;
    allowRead = raw.toolchainReads ++ raw.nixReads ++ raw.sshSigningReads;

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
    # again here, plus their .bak sibling (see #126). hooksPath and settingsPath close a same-session escape:
    # PreToolUse hooks run unsandboxed, so a sandboxed command could otherwise overwrite rtk-hook.sh or flip
    # permissions.deny/sandbox.enabled for the next session. Full trail: docs/sandbox-notes.md.
    denyWrite =
      raw.bakCarveouts
      ++ credentialBaks
      ++ [
        raw.sandbox.hooksPath
        raw.sandbox.settingsPath
      ];
  };

  # Full programs.claude-code.settings.sandbox.network block, same reasoning as claudeCodeSandboxFilesystem.
  # tags: claude-code.sandbox
  claudeCodeSandboxNetwork = {
    inherit (raw) allowedDomains;

    # Without this every nix subcommand fails to reach its daemon.
    allowUnixSockets = [ "/nix/var/nix/daemon-socket/socket" ];

    # gh/terraform/kubectl validate TLS via Security.framework -> trustd, which Seatbelt blocks by default
    # (`x509: OSStatus -26276`, even for a valid cert; curl/git/Node verify in-process and are unaffected).
    # anthropics/claude-code#26466.
    allowMachLookup = [ "com.apple.trustd.agent" ];
  };
in
raw
// {
  inherit
    claudeCodeCredentialDenyRules
    opencodeBashRules
    claudeCodeSandboxFilesystem
    claudeCodeSandboxNetwork
    ;
}
