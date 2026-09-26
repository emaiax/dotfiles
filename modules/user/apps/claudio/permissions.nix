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
  extraDeny = permissions.commands.extraDeny or [ ];
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
      inherit extraAllow extraAsk extraDeny;

      allow = [
        "cat"
        "chmod"
        "command"
        "docker"
        "echo"
        "find"
        "fj"
        "gh"
        "git"
        "grep"
        "head"
        "jq"
        "just"
        "ls"
        "nix"
        "readlink"
        "rg"
        "rtk"
        "sort"
        "ssh -o ProxyCommand="
        "tail"
        "which"
      ]
      ++ extraAllow;

      # destructive and hard to undo
      ask = [
        "docker prune"
        "git push"
        "python3"
        "rm -rf"
        # "git checkout --" # checkout changes to tracked files only
        # "git clean" # remove untracked files from the working directory
        # "git rebase" # reapply commits on top of another base tip
        # "git reset --hard"
        # "git restore" # restore changes to tracked files only

      ]
      ++ extraAsk;

      # matched literally rather than as a prefix
      askExact = [ "git checkout ." ];

      # irreversible. universal deny tier across all agents and tools
      deny = [
        "gh pr close"
        "gh pr comment"
        "gh pr create"
        "gh pr merge"
        "gh issue close"
        "gh issue comment"
        "gh issue create"
        "gh issue edit"
      ]
      ++ extraDeny;

      # reversible: rendered as prose in autoMode.soft_deny instead of a hard deny (sandbox-notes.md).
      denySoft = [
        # "fj issue create"
        # "fj issue edit"
        # "fj issue comment"
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

    filesystem = {
      home = "${home}";

      # unix sockets that the agent should allow read and write access to
      sockets = unixSockets;

      # sandbox: claude's Seatbelt boundary policy for filesystem paths every profile needs access to
      #
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

  # Backend adapters
  antigravity = import ./antigravity/settings.nix { inherit lib policy; };
  claudeCode = import ./claude-code/settings.nix { inherit lib policy; };
  opencode = import ./opencode/settings.nix { inherit lib policy; };
in
{
  inherit
    antigravity
    claudeCode
    opencode
    policy
    ;

  inherit (claudeCode) forProfile;
}
