# Permissions for commands, filesystem paths, and network domains policy shared across every coding agent and
# profile in this repo. These are the loosest any profile will ever be, since they land in the user layer and a
# higher-precedence layer cannot loosen them.
#
# Structure: `policy` is the single source of truth, grouped by domain (commands, credentials, filesystem,
# network, sandbox). mkClaudeCodePermissions, mkClaudeCodeSandbox, and mkOpencodePermissions each take that one
# policy and render it into one consumer's native settings shape, so claude-code/default.nix and
# opencode/default.nix each just wire in their own branch instead of carrying their own translation logic.
{ home, lib, ... }:
let
  policy = {
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

      # Reversible, so these become prose in auto-mode.nix's soft_deny, which claudio-thebot can carve an
      # exception out of, and only claudeCode.permissions.deny renders them that way. OpenCode has no classifier,
      # so opencode.permission.bash renders denyHard and denySoft both as plain denies.
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

      # Derived globs that would widen the rule if applied as a plain prefix. `git checkout --` would become
      # `git checkout --*`, swallowing `--track` and `--force`. Only opencode.permission.bash consumes this.
      opencodePatterns = {
        "git checkout --" = "git checkout -- *";
      };

      # docker doesn't compose with the sandbox; gh/fj fail cert validation under it (trustd mach-lookup
      # blocked). Excluded commands run fully unwrapped: a hole, not a containment. Each needs a glob (bare
      # names aren't matched) and an `rtk `-prefixed twin, since the PreToolUse hook rewrites gh/fj commands
      # before this matches against them. Full background: docs/sandbox-notes.md.
      bypassSandboxSeatbelt = [
        "docker *"
        "rtk docker *"
        "gh *"
        "rtk gh *"
        "fj *"
        "rtk fj *"
      ];
    };

    # sandbox: claude's Seatbelt boundary policy for filesystem paths every profile needs access to
    filesystem = {
      # filesystem paths that must stay out of every agent's reach, no matter which tool asks for them
      # claudeCode.sandbox.filesystem denies these to the sandboxed Bash subprocess, and claudeCode.permissions
      # denies them to the native Read/Edit tools, which the sandbox never sees.
      #
      # OpenCode has no path-based deny mechanism of its own yet, so only claude-code's two halves read this today.
      #
      credentials = {
        # Read/Edit deny rules need a /** suffix to reach files nested inside these directories
        dirs = [
          "${home}/.aws"
          "${home}/.config/1Password"
          "${home}/.config/sops"
          "${home}/.gnupg"
          "${home}/.ssh"
        ];

        # Read/Edit is only half of the credential policy: denyRead/denyWrite only confines Bash in sandbox.
        # Write(path) rules are silently never checked, so Edit covers Write too.
        files = [
          "${home}/.claude/.credentials.json"
          "${home}/.netrc"
          "${home}/.npmrc"

          # Deny the credential file, never the config directory around it
          #
          # ~/.config/opencode - OpenCode configs
          # ~/.local/share - OpenCode credentials
          #
          "${home}/.local/share/opencode/auth.json"
          "${home}/.local/share/opencode/mcp-auth.json"
        ];
      };

      # Toolchains, not personal data: denying $HOME wholesale takes out npm/node/asdf too. These need both read
      # and write access, so mkClaudeCodeSandbox's allowRead and allowWrite both draw from this one list instead
      # of each retyping it, which is how allowWrite drifted out of sync with allowRead before.
      toolchainReadWrite = [
        "${home}/.asdf"
        "${home}/.bun"
        "${home}/.bundle"
        "${home}/.cache"
        "${home}/.claude"
        "${home}/.config"
        "${home}/.gem"
        "${home}/.gitconfig"
        "${home}/.hex"
        "${home}/.local"
        "${home}/.mix"
        "${home}/.npm"
        "${home}/.terraform.d"

        "${home}/Library/Application Support/rtk" # RTK's global init writes RTK.md and its filters template here
        "${home}/Library/Caches" # treefmt, which `nix fmt` runs, caches here rather than under XDG

        # workspaces
        "${home}/code"
        "${home}/go"
      ];

      # Read-only additions on top of toolchainReadWrite.
      toolchainReadOnly = [
        # needed just to reach the normal per-item ACL prompt; doesn't bypass it
        "${home}/Library/Keychains" # git push`'s credential store still fails here with a known, accepted gap (docs/sandbox-notes.md)

        # the Bash tool runs commands through the login shell
        "${home}/.zshrc"
        "${home}/.zshenv"

        # nix breaks under the sandbox if can't read its cache and state dirs
        "${home}/.cache/nix"
        "${home}/.local/state/nix"
        "${home}/.nix-defexpr"
        "${home}/.nix-profile"

        # ssh agent signing: the agent socket is ephemeral, so the sandbox can't allowWrite it,
        # but it can allowRead the public keys and config that the agent reads to sign commits.
        # ~/.ssh itself is denied below (credentials.dirs), but Seatbelt is last-match-wins and Claude Code's
        # profile generator specifically re-emits allowRead entries after the deny they're nested under
        # (anthropic-experimental/sandbox-runtime, src/sandbox/macos-sandbox-utils.ts: "denyOnly: deny reads
        # from these paths ... allowWithinDeny: re-allow reads within denied regions ... allowWithinDeny takes
        # precedence over denyOnly"), so these four still resolve readable despite the broader deny.
        "${home}/.ssh/*.pub"
        "${home}/.ssh/allowed_signers"
        "${home}/.ssh/config"
        "${home}/.ssh/known_hosts"
      ];
    };

    # sandbox: network egress and IPC the sandbox otherwise blocks by default
    network = {
      allowedDomains = [
        "*.emx.casa" # homelab forgejo, LAN-only; already public in the README badges and CI workflows
        "api.github.com" # gh api
        "github.com" # git-over-https
      ];

      allowUnixSockets = [ "/nix/var/nix/daemon-socket/socket" ]; # allow nix subcommand to reach its daemon

      # gh/terraform/kubectl validate TLS via Security.framework -> trustd, which Seatbelt blocks by default
      # (`x509: OSStatus -26276`, even for a valid cert; curl/git/Node verify in-process and are unaffected)
      allowMachLookup = [ "com.apple.trustd.agent" ]; # anthropics/claude-code#26466.
    };
  };

  # A sibling `.bak` (backupFileExtension = "bak") could ride the same allowRead/allowWrite grant back in as the
  # file it backs up, so every credential file needs its own `.bak` denied too, not just the ones nested inside
  # an allowed tree today. Shared between mkClaudeCodePermissions and mkClaudeCodeSandbox.
  credentialBaks = map (p: "${p}.bak") policy.filesystem.credentials.files;

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

  # OpenCode has no ask/deny split by classifier, so denyHard and denySoft both render as plain denies here.
  # last-matching-rule-wins, evaluated in *declaration* order: Nix attrsets don't preserve that order when
  # serialized to JSON (keys come out alphabetical), so every rule after the "*" catch-all has to be pinned with
  # entryAfter or it can silently reorder ahead of it.
  opencodePrefixRule = action: cmd: {
    name = policy.commands.opencodePatterns.${cmd} or "${cmd}*";
    value = lib.hm.dag.entryAfter [ "*" ] action;
  };
  opencodeExactRule = action: cmd: {
    name = cmd;
    value = lib.hm.dag.entryAfter [ "*" ] action;
  };

  # programs.claude-code.settings.permissions: the native Read/Edit/Bash gate, ask/deny hold in every mode,
  # unlike allow and autoMode.
  mkClaudeCodePermissions =
    policy:
    let
      credentialDenyRules =
        lib.concatMap claudeCodeFileDenyRules (policy.filesystem.credentials.files ++ credentialBaks)
        ++ lib.concatMap claudeCodeDirDenyRules policy.filesystem.credentials.dirs;
    in
    {
      ask =
        map claudeCodePrefixRule (withRtkTwin policy.commands.ask)
        ++ map claudeCodeExactRule (withRtkTwin policy.commands.askExact);

      # hard tier only; reversible ones are soft_deny in auto-mode.nix
      deny = map claudeCodePrefixRule (withRtkTwin policy.commands.denyHard) ++ credentialDenyRules;
    };

  # programs.claude-code.settings.sandbox.{bypassSecurityCommands,filesystem,network}: the Seatbelt boundary itself.
  mkClaudeCodeSandbox = policy: {
    excludedCommands = policy.commands.bypassSandboxSeatbelt;
    network = policy.network;

    # Reads: allow-everything by default upstream
    # Writes: deny-by-default, and cwd is writable implicitly
    filesystem = {
      allowRead = policy.filesystem.toolchainReadOnly ++ policy.filesystem.toolchainReadWrite;
      allowWrite = policy.filesystem.toolchainReadWrite;

      denyRead = [ home ] ++ policy.filesystem.credentials.dirs ++ policy.filesystem.credentials.files;
      denyWrite = [ home ] ++ policy.filesystem.credentials.dirs ++ policy.filesystem.credentials.files; # [ home ] is redundant but explicit
    };
  };

  # programs.opencode.settings.permission.
  mkOpencodePermissions = policy: {
    read = {
      "*" = "allow";

      # default .env protection explicit: a bare "allow" string here isn't documented to preserve it
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
    external_directory = "ask"; # Touching paths outside the project: flag it.
    doom_loop = "deny"; # Same tool call repeated 3x with identical input: kill it, don't ask.

    bash = {
      "*" = "allow";
    }
    // builtins.listToAttrs (
      map (opencodePrefixRule "ask") policy.commands.ask
      ++ map (opencodePrefixRule "deny") (policy.commands.denyHard ++ policy.commands.denySoft)
      ++ map (opencodeExactRule "ask") policy.commands.askExact
    );
  };
in
{
  inherit policy;

  claudeCode = {
    permissions = mkClaudeCodePermissions policy;
    sandbox = mkClaudeCodeSandbox policy;
  };

  opencode = {
    permission = mkOpencodePermissions policy;
  };
}
