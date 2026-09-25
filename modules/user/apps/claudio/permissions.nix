# Command, filesystem, and network policy shared across every coding agent and profile in this repo. `policy`
# is data only: docs/sandbox-notes.md's "permissions.nix: policy is data" section covers the full architecture.
{
  home,
  lib,
  cfg ? { },
  permissions ? cfg.permissions or { },
  ...
}:
let
  extraAllow = permissions.commands.extraAllow or [ ];
  extraAsk = permissions.commands.extraAsk or [ ];
  extraDenyHard = permissions.commands.extraDenyHard or [ ];
  extraAllowedDomains = permissions.network.extraAllowedDomains or [ ];
  extraCredentials = permissions.filesystem.extraCredentials or [ ];
  extraToolchainPaths = permissions.filesystem.extraToolchainPaths or [ ];

  # allowUnixSockets covers connecting and stat'ing the path
  unixSockets = [
    "/nix/var/nix/daemon-socket/socket" # allow nix subcommand to reach its daemon
    "${home}/.docker/run/docker.sock" # allow docker subcommand to reach its daemon
  ];

  policy = {
    commands = {
      # ssh is a special case: it needs to be allowed to run
      allow = [ "ssh -o ProxyCommand=" ] ++ extraAllow;
      inherit extraAllow extraAsk extraDenyHard;

      ask = [
        "git push"

        # Destructive and hard to undo.
        "git reset --hard"
        "git checkout --"
        "git restore"
        "git clean"
        "git rebase"
        "rm -rf"
      ]
      ++ extraAsk;

      # Matched literally rather than as a prefix.
      askExact = [ "git checkout ." ];

      # Irreversible. Deny unions across every settings source (a `--settings` file can't remove one), so
      # this stays out of the shared base; mkClaudeCodePermissions's `hardDeny` arg opts a profile into it.
      denyHard = [
        "gh pr merge"
        "gh release"
        "fj pr merge"
        "fj release"
      ]
      ++ extraDenyHard;

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

        extra = extraCredentials;
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
      ]
      ++ extraToolchainPaths;

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
      ]
      ++ extraAllowedDomains;

      # gh/terraform/kubectl validate TLS via Security.framework -> trustd, which Seatbelt blocks by default
      # (`x509: OSStatus -26276`, even for a valid cert; curl/git/Node verify in-process and are unaffected)
      allowMachLookup = [ "com.apple.trustd.agent" ]; # anthropics/claude-code#26466.

      allowUnixSockets = unixSockets;
    };
  };

  # =========================================================================
  # 2. Claude Code Adapter (Seatbelt sandbox & native tool rules)
  # =========================================================================
  claudeCodeBackend =
    let
      cleanCmd = cmd: lib.removeSuffix " " (lib.removeSuffix "*" (lib.removeSuffix " *" cmd));
      prefixRule = cmd: "Bash(${cleanCmd cmd}:*)";
      exactRule = cmd: "Bash(${cmd})";

      withRtkTwin =
        cmds:
        lib.concatMap (cmd: [
          cmd
          "rtk ${cmd}"
        ]) cmds;

      absPath = path: lib.removePrefix "/" path;

      # Auto-defense: file rules + .bak backup twin rules
      fileRules = path: [
        "Read(//${absPath path})"
        "Edit(//${absPath path})"
        "Read(//${absPath path}.bak)"
        "Edit(//${absPath path}.bak)"
      ];

      # Auto-defense: directory rules (recursive /**)
      dirRules = path: [
        "Read(//${absPath path}/**)"
        "Edit(//${absPath path}/**)"
      ];

      # Auto-defense: extra/unknown path (covers file, .bak, and recursive dir)
      extraPathRules = path: (fileRules path) ++ (dirRules path);

      credentialDenyRules =
        lib.concatMap fileRules policy.filesystem.credentials.files
        ++ lib.concatMap dirRules policy.filesystem.credentials.dirs
        ++ lib.concatMap extraPathRules (policy.filesystem.credentials.extra or [ ]);

      askRules =
        map prefixRule (withRtkTwin policy.commands.ask)
        ++ map exactRule (withRtkTwin policy.commands.askExact);

      mkPermissions =
        {
          hardDeny ? false,
        }:
        let
          hardDenyRules = lib.optionals hardDeny (map prefixRule (withRtkTwin policy.commands.denyHard));
        in
        {
          allow = map prefixRule (withRtkTwin policy.commands.allow);
          ask = askRules;
          deny = hardDenyRules ++ credentialDenyRules;
        };

      mkSandbox = {
        excludedCommands = policy.commands.bypassSandboxSeatbelt;
        network = policy.network;
        filesystem = {
          disabled = true; # allowWrite is a no-op upstream; network sandbox stays active
          allowRead =
            unixSockets ++ policy.filesystem.toolchainReadOnly ++ policy.filesystem.toolchainReadWrite;
          allowWrite = policy.filesystem.toolchainReadWrite;
          denyRead = [
            home
          ]
          ++ policy.filesystem.credentials.dirs
          ++ policy.filesystem.credentials.files
          ++ (policy.filesystem.credentials.extra or [ ]);
          denyWrite = [
            home
          ]
          ++ policy.filesystem.credentials.dirs
          ++ policy.filesystem.credentials.files
          ++ (policy.filesystem.credentials.extra or [ ]);
        };
      };
    in
    {
      inherit credentialDenyRules mkPermissions mkSandbox;
    };

  # =========================================================================
  # 3. Antigravity CLI Adapter (settings.json approvals)
  # =========================================================================
  antigravityBackend =
    let
      exactRule = cmd: "command(${cmd})";
      allowRule =
        cmd:
        if lib.hasPrefix "command(" cmd then
          cmd
        else if lib.hasSuffix "*" cmd then
          "command(${cmd})"
        else
          "command(${cmd} *)";

      baseApprovals = [
        "command(cat *)"
        "command(chmod *)"
        "command(echo *)"
        "command(find *)"
        "command(fj *)"
        "command(git *)"
        "command(grep *)"
        "command(head *)"
        "command(jq *)"
        "command(just *)"
        "command(ls *)"
        "command(nix *)"
        "command(python3 *)"
        "command(readlink *)"
        "command(rtk *)"
        "command(sort *)"
        "command(tail *)"
        "command(which *)"
      ];
    in
    {
      permissions = {
        allow =
          baseApprovals
          ++ map exactRule (lib.filter (c: c == "ssh -o ProxyCommand=") policy.commands.allow)
          ++ map allowRule (policy.commands.extraAllow or [ ]);
      };
    };

  # =========================================================================
  # 4. OpenCode Adapter (permission matrix)
  # =========================================================================
  opencodeBackend = {
    permission = {
      read = {
        "*" = "allow";
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
      external_directory = "ask";
      doom_loop = "deny";
      bash = {
        "*" = "allow";
      }
      // (lib.genAttrs (policy.commands.extraAllow or [ ]) (_: "allow"));
    };
  };

  # =========================================================================
  # 5. Profile Bundles & Dispatcher
  # =========================================================================
  claudeCode = {
    sandbox = claudeCodeBackend.mkSandbox;
    user = claudeCodeBackend.mkPermissions { hardDeny = true; };
    yolo = { };
    credentialDenyOnly = {
      deny = claudeCodeBackend.credentialDenyRules;
    };
  };

  forProfile =
    profile:
    if profile == "claudio" then
      claudeCode.user // { defaultMode = "auto"; }
    else if profile == "claudio-yolo" then
      claudeCode.credentialDenyOnly
    else if profile == "claudio-thebot" then
      claudeCode.yolo
    else
      throw "Unknown claudio profile: ${profile}";
in
{
  inherit policy forProfile;

  antigravity = {
    permissions = antigravityBackend.permissions;
  };

  inherit claudeCode;

  opencode = {
    permission = opencodeBackend.permission;
  };
}
