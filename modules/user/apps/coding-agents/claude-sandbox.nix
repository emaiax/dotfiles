# Default sandbox layer for every Claude Code session (see #121).
#
# Confines Bash and its children only. Read/Edit/Write go through the permission system, so a path policy covering both has to be written twice; this is the Bash half. Profiles layer on top via `--settings`, which merges, so they inherit every deny here.
#
# Two ways to write a rule that silently does nothing: a trailing slash voids the entry on 2.1.222 (fixed in 2.1.224), and a glob like `$HOME/*` matches nothing and fails open.
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
    "${home}/.config/opencode"
    "${home}/.config/sops"
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

    # Without this every nix subcommand fails to reach its daemon.
    network.allowUnixSockets = [ "/nix/var/nix/daemon-socket/socket" ];

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
      ];
    };
  };
}
