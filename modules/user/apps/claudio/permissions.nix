# Command, filesystem, and network policy shared across every coding agent and profile in this repo. `policy`
# is data only: docs/sandbox-notes.md's "permissions.nix: policy is data" section covers the full architecture.
{ home, lib, ... }:
let
  # allowUnixSockets covers connecting and stat'ing the path
  unixSockets = [
    "/nix/var/nix/daemon-socket/socket" # allow nix subcommand to reach its daemon
    "${home}/.docker/run/docker.sock" # allow docker subcommand to reach its daemon
  ];

  policy = {
    commands = {
      # ssh is a special case: it needs to be allowed to run
      allow = [ "ssh -o ProxyCommand=" ];

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

      # Irreversible. Deny unions across every settings source (a `--settings` file can't remove one), so
      # this stays out of the shared base; mkClaudeCodePermissions's `hardDeny` arg opts a profile into it.
      denyHard = [
        "gh pr merge"
        "gh release"
        "fj pr merge"
        "fj release"
      ];

      # Reversible: rendered as prose in autoMode.soft_deny instead of a hard deny (sandbox-notes.md).
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

      # docker/gh/fj/ssh don't compose with the sandbox; excluded commands run fully unwrapped, a hole rather
      # than containment. Needs an `rtk `-prefixed twin per entry: docs/sandbox-notes.md's "escape" section.
      bypassSandboxSeatbelt = [
        "docker *"
        "rtk docker *"
        "gh *"
        "rtk gh *"
        "fj *"
        "rtk fj *"
        "ssh *"
        "rtk ssh *"
      ];
    };

    # sandbox: claude's Seatbelt boundary policy for filesystem paths every profile needs access to
    filesystem = {
      # Credential deny is two independent layers (sandbox filesystem vs Read/Edit tool rules): sandbox-notes.md.
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

          # Deny the credential file itself, not its parent config dir. Below: OpenCode's auth files.
          "${home}/.local/share/opencode/auth.json"
          "${home}/.local/share/opencode/mcp-auth.json"
        ];
      };

      # One list, not two, so allowRead/allowWrite can't drift out of sync (sandbox-notes.md).
      toolchainReadWrite = [
        "${home}/.asdf"
        "${home}/.bun"
        "${home}/.bundle"
        "${home}/.cache"
        "${home}/.claude"
        "${home}/.claude-mem"
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

        # Readable despite the ~/.ssh deny below: sandbox-notes.md's "SSH agent signing keys" section.
        "${home}/.ssh/*.pub"
        "${home}/.ssh/allowed_signers"
        "${home}/.ssh/config"
        "${home}/.ssh/known_hosts"
      ];
    };

    # sandbox: network egress and IPC the sandbox otherwise blocks by default
    network = {
      allowedDomains = [
        "*.emx.casa"
        "*.local" # homelab guests via mDNS
        "api.github.com" # gh api
        "app.asana.com" # asana api
        "github.com" # git-over-https
        "registry.yarnpkg.com" # yarn install
      ];

      # gh/terraform/kubectl validate TLS via Security.framework -> trustd, which Seatbelt blocks by default
      # (`x509: OSStatus -26276`, even for a valid cert; curl/git/Node verify in-process and are unaffected)
      allowMachLookup = [ "com.apple.trustd.agent" ]; # anthropics/claude-code#26466.

      allowUnixSockets = unixSockets;
    };
  };

  # A sibling `.bak` could ride the same allow grant back in as the file it backs up (sandbox-notes.md).
  credentialBaks = map (p: "${p}.bak") policy.filesystem.credentials.files;

  # `Bash(x:*)` matches any arguments; `Bash(x)` matches only that literal invocation.
  claudeCodePrefixRule = cmd: "Bash(${cmd}:*)";
  claudeCodeExactRule = cmd: "Bash(${cmd})";

  # rtk's PreToolUse hook rewrites recognized commands to `rtk <cmd>`, defeating a bare-command gate silently.
  # A twin per gate, not a fixed list, since rtk's rewrite inventory can grow.
  withRtkTwin =
    cmds:
    lib.concatMap (cmd: [
      cmd
      "rtk ${cmd}"
    ]) cmds;

  # `//path` is filesystem-root-absolute, `/path` matches nothing, dirs need `/**` for nested files.
  claudeCodeAbsRule = path: lib.removePrefix "/" path;

  claudeCodeFileDenyRules = path: [
    "Read(//${claudeCodeAbsRule path})"
    "Edit(//${claudeCodeAbsRule path})"
  ];

  claudeCodeDirDenyRules = path: [
    "Read(//${claudeCodeAbsRule path}/**)"
    "Edit(//${claudeCodeAbsRule path}/**)"
  ];

  # The two universal pieces every profile gets regardless of yolo/hardDeny status: prompting on destructive
  # git/rm commands, and never letting a credential file through. Shared by the base and full permissions below.
  claudeCodeAskRules =
    policy:
    map claudeCodePrefixRule (withRtkTwin policy.commands.ask)
    ++ map claudeCodeExactRule (withRtkTwin policy.commands.askExact);

  claudeCodeCredentialDenyRules =
    policy:
    lib.concatMap claudeCodeFileDenyRules (policy.filesystem.credentials.files ++ credentialBaks)
    ++ lib.concatMap claudeCodeDirDenyRules policy.filesystem.credentials.dirs;

  # The full bundle for a profile that wants its own `allow` too (claudio): `hardDeny` opts into the
  # irreversible-command tier, see the comment above `denyHard` in `policy.commands`.
  mkClaudeCodePermissions =
    {
      policy,
      hardDeny ? false,
    }:
    let
      hardDenyRules = lib.optionals hardDeny (
        map claudeCodePrefixRule (withRtkTwin policy.commands.denyHard)
      );
    in
    {
      allow = map claudeCodePrefixRule (withRtkTwin policy.commands.allow);
      ask = claudeCodeAskRules policy;
      deny = hardDenyRules ++ claudeCodeCredentialDenyRules policy;
    };

  # programs.claude-code.settings.sandbox.{bypassSecurityCommands,filesystem,network}: the Seatbelt boundary itself.
  mkClaudeCodeSandbox = policy: {
    excludedCommands = policy.commands.bypassSandboxSeatbelt;
    network = policy.network;

    # Reads: allow-everything by default upstream
    # Writes: deny-by-default, and cwd is writable implicitly
    filesystem = {
      disabled = true; # allowWrite is a no-op upstream, docs/sandbox-notes.md; network sandbox stays on

      allowRead =
        unixSockets ++ policy.filesystem.toolchainReadOnly ++ policy.filesystem.toolchainReadWrite;

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
    };
  };
in
{
  inherit policy;

  claudeCode = {
    sandbox = mkClaudeCodeSandbox policy;

    # claudio.nix: full ask/deny bundle plus the irreversible-command tier.
    user = mkClaudeCodePermissions {
      inherit policy;
      hardDeny = true;
    };

    # claudio-thebot.nix: the literal empty object, zero permissions on purpose (sandbox-notes.md's
    # "claude-yolo: what it actually trades away" section covers both this and the bundle below).
    yolo = { };

    # claudio-yolo.nix: the one protection it keeps despite otherwise defining no permissions of its own.
    credentialDenyOnly = {
      deny = claudeCodeCredentialDenyRules policy;
    };
  };

  opencode = {
    permission = mkOpencodePermissions policy;
  };
}
