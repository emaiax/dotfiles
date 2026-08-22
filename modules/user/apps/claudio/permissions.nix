# Permissions for commands, filesystem paths, and network domains policy shared across every coding agent and profile in this repo.
# These are the loosest any profile will ever be, since they land in the user layer and a higher-precedence layer cannot loosen them.
#
# Structure: `commands` and `credentials` are raw, backend-agnostic input. `claudeCode` and `opencode` are each
# backend's own tree, already rendered into its native settings shape, so claude-code.nix, sandbox.nix, and
# opencode/default.nix each just wire in their own branch instead of carrying their own translation logic.
{ home, lib }:
let
  commands = {
    ask = [
      "git push"

      # Destructive and hard to undo.
      "git reset --hard"
      "git checkout --"
      "git restore"
      "git clean"
      "git rebase"
      "rm -rf"
    ];

    # Matched literally rather than as a prefix.
    askExact = [ "git checkout ." ];

    # Irreversible, so these go to `permissions.deny` where nothing overrides them.
    denyHard = [
      "gh pr merge"
      "gh release"
      "fj pr merge"
      "fj release"
    ];

    # Reversible, so these become prose in auto-mode.nix's soft_deny, which claudio-thebot can carve an exception
    # out of, and only claudeCode.permissions.deny renders them that way. OpenCode has no classifier, so
    # opencode.bash renders denyHard and denySoft both as plain denies.
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

    # No allowlist: `ls` and `cat` are aliases resolving to nix store paths that no name-based rule matches, so an
    # allowlist blocks them however it is written.

    # Derived globs that would widen the rule if applied as a plain prefix. `git checkout --` would become
    # `git checkout --*`, swallowing `--track` and `--force`. Only opencode.bash consumes this.
    opencodePatterns = {
      "git checkout --" = "git checkout -- *";
    };
  };

  # Filesystem paths that must stay out of every agent's reach, no matter which tool asks for them.
  # claudeCode.sandbox.filesystem denies these to the sandboxed Bash subprocess, and claudeCode.permissions
  # denies them to the native Read/Edit tools, which the sandbox never sees. OpenCode has no path-based deny
  # mechanism of its own yet, so only claude-code's two halves read this today.
  credentials = {
    # Directories: Read/Edit deny rules need a /** suffix to reach files nested inside.
    dirs = [
      "${home}/.aws"
      "${home}/.config/1Password"
      "${home}/.config/sops"
      "${home}/.gnupg"
    ];

    # Single files.
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

    # Files above nested inside an allowRead/allowWrite tree by name, not a wholesale-denied directory, so a
    # sibling `.bak` (backupFileExtension = "bak") could ride the same grant back in and needs its own carve-out.
    # Only .credentials.json qualifies today.
    bakCarveouts = [
      "${home}/.claude/.credentials.json"
    ];
  };

  credentialBaks = map (p: "${p}.bak") credentials.bakCarveouts;

  # `Bash(x:*)` matches any arguments; `Bash(x)` matches only that literal invocation.
  claudeCodePrefixRule = cmd: "Bash(${cmd}:*)";
  claudeCodeExactRule = cmd: "Bash(${cmd})";

  # rtk's PreToolUse hook rewrites recognized commands to `rtk <cmd>`, and permission rules match against that
  # rewritten string, so a bare-command gate is silently defeated for anything rtk rewrites. A twin per gate
  # rather than a fixed list, since rtk's rewrite inventory can grow.
  withRtkTwin =
    cmds:
    lib.concatMap (cmd: [
      cmd
      "rtk ${cmd}"
    ]) cmds;

  # Read/Edit is only half of the credential policy: sandbox.filesystem.denyRead/denyWrite only confines Bash.
  # Write(path) rules are silently never checked, so Edit covers Write too. `//path` is filesystem-root-absolute,
  # `/path` matches nothing, and dirs need `/**` for nested files.
  claudeCodeAbsRule = path: lib.removePrefix "/" path;
  claudeCodeFileDenyRules = path: [
    "Read(//${claudeCodeAbsRule path})"
    "Edit(//${claudeCodeAbsRule path})"
  ];
  claudeCodeDirDenyRules = path: [
    "Read(//${claudeCodeAbsRule path}/**)"
    "Edit(//${claudeCodeAbsRule path}/**)"
  ];
  claudeCodeCredentialDenyRules =
    lib.concatMap claudeCodeFileDenyRules (credentials.files ++ credentialBaks)
    ++ lib.concatMap claudeCodeDirDenyRules credentials.dirs;

  # OpenCode has no ask/deny split by classifier, so denyHard and denySoft both render as plain denies here.
  # last-matching-rule-wins, evaluated in *declaration* order: Nix attrsets don't preserve that order when
  # serialized to JSON (keys come out alphabetical), so every rule after the "*" catch-all has to be pinned with
  # entryAfter or it can silently reorder ahead of it.
  opencodePrefixRule = action: cmd: {
    name = commands.opencodePatterns.${cmd} or "${cmd}*";
    value = lib.hm.dag.entryAfter [ "*" ] action;
  };
  opencodeExactRule = action: cmd: {
    name = cmd;
    value = lib.hm.dag.entryAfter [ "*" ] action;
  };

  # Sandbox policy for Claude Code's Seatbelt boundary: filesystem paths every profile needs read access to, plus
  # the commands and domains that sit outside it. OpenCode has no sandbox mechanism, so none of this applies there.
  nixReads = [
    "${home}/.cache/nix"
    "${home}/.local/state/nix"
  ];

  # Toolchains, not personal data: denying $HOME wholesale takes out npm/node/asdf too.
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
  sshSigningReads = [
    "${home}/.ssh/allowed_signers"
    "${home}/.ssh/config"
    "${home}/.ssh/github"
    "${home}/.ssh/github.pub"
    "${home}/.ssh/known_hosts"
  ];

  # homelab domain is patched in at runtime by hooks/homelab-network-hook.sh
  allowedDomains = [
    "github.com" # git-over-https
    "api.github.com" # gh api
  ];

  # Plain path constants that claude-code.nix and sandbox.nix both need to agree on. They're sibling files,
  # neither imports the other, so without a shared spot they silently drift apart (see #126). settingsFile backs
  # sandbox.filesystem.denyWrite below: PreToolUse hooks run unsandboxed, so a sandboxed command could otherwise
  # overwrite a hook script or flip permissions.deny/sandbox.enabled for the next session.
  sandboxPaths = {
    settingsFile = "${home}/code/dotfiles/modules/user/apps/claudio/claude-code/settings.json";
    hooksDir = "${home}/.claude/hooks";
  };
in
{
  inherit commands credentials;

  claudeCode = {
    permissions = {
      # ask/deny hold in every mode, unlike allow and autoMode.
      ask =
        map claudeCodePrefixRule (withRtkTwin commands.ask)
        ++ map claudeCodeExactRule (withRtkTwin commands.askExact);

      # hard tier only; reversible ones are soft_deny in auto-mode.nix
      deny = map claudeCodePrefixRule (withRtkTwin commands.denyHard) ++ claudeCodeCredentialDenyRules;
    };

    sandbox = {
      # docker doesn't compose with the sandbox; gh/fj fail cert validation under it (trustd mach-lookup blocked).
      # Excluded commands run fully unwrapped: a hole, not a containment. Each needs a glob (bare names aren't
      # matched) and an `rtk `-prefixed twin, since the PreToolUse hook rewrites gh/fj commands before this
      # matches against them. Full background: docs/sandbox-notes.md.
      excludedCommands = [
        "docker *"
        "rtk docker *"
        "gh *"
        "rtk gh *"
        "fj *"
        "rtk fj *"
      ];

      filesystem = {
        # Reads are allow-everything by default upstream; deny $HOME, allow back the toolchain.
        # credentialBaks: same reasoning as the denyWrite carve-out below.
        denyRead = [ home ] ++ credentials.dirs ++ credentials.files ++ credentialBaks;
        allowRead = toolchainReads ++ nixReads ++ sshSigningReads;

        # Writes are already deny-by-default, and cwd is writable implicitly. Package managers need to write
        # where they install.
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
        # again here, plus their .bak sibling (see #126). hooksDir and settingsFile close a same-session escape:
        # PreToolUse hooks run unsandboxed, so a sandboxed command could otherwise overwrite rtk-hook.sh or flip
        # permissions.deny/sandbox.enabled for the next session. Full trail: docs/sandbox-notes.md.
        denyWrite =
          credentials.bakCarveouts
          ++ credentialBaks
          ++ [
            sandboxPaths.hooksDir
            sandboxPaths.settingsFile
          ];
      };

      network = {
        inherit allowedDomains;

        # Without this every nix subcommand fails to reach its daemon.
        allowUnixSockets = [ "/nix/var/nix/daemon-socket/socket" ];

        # gh/terraform/kubectl validate TLS via Security.framework -> trustd, which Seatbelt blocks by default
        # (`x509: OSStatus -26276`, even for a valid cert; curl/git/Node verify in-process and are unaffected).
        # anthropics/claude-code#26466.
        allowMachLookup = [ "com.apple.trustd.agent" ];
      };

      paths = sandboxPaths;
    };
  };

  opencode = {
    permission = {
      read = {
        "*" = "allow";
        # Keep the default .env protection explicit: a bare "allow" string here isn't documented to preserve it.
        "*.env" = "deny";
        "*.env.*" = "deny";
        "*.env.example" = "allow";
      };
      glob = "allow";
      grep = "allow";
      lsp = "allow";
      edit = "allow";
      webfetch = "allow";
      websearch = "allow";
      task = "allow";
      # Touching paths outside the project: flag it.
      external_directory = "ask";
      # Same tool call repeated 3x with identical input: kill it, don't ask.
      doom_loop = "deny";

      bash = {
        "*" = "allow";
      }
      // builtins.listToAttrs (
        map (opencodePrefixRule "ask") commands.ask
        ++ map (opencodePrefixRule "deny") (commands.denyHard ++ commands.denySoft)
        ++ map (opencodeExactRule "ask") commands.askExact
      );
    };
  };
}
