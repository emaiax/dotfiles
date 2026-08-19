# Default sandbox layer for every Claude Code session (see issue #121).
#
# Replaces the `claude-trust` posture (`claude --dangerously-skip-permissions`,
# no boundary at all) with Seatbelt confinement plus a deny-by-default read
# scope. Named profiles land on top of this via `--settings`, which merges
# rather than replaces, so they inherit every deny below.
#
# Only Bash and its child processes are confined; Read/Edit/Write go through the
# permission system instead. Any path policy that must cover both has to be
# written twice — this file is the Bash half.
#
# Every path is absolute and carries NO trailing slash: on 2.1.222 a trailing
# slash silently voids the entry (fixed upstream in 2.1.224). Globs are worse
# than useless here — `denyRead = [ "$HOME/*" ]` matches nothing and fails
# *open*, verified live on this machine.
{ config, ... }:
let
  home = config.home.homeDirectory;

  # Nix is the whole point of this repo and breaks in three separate ways under
  # the sandbox: the fetcher cache, the eval/state dirs, and the daemon socket.
  # All three were found by running `nix eval` until it stopped erroring.
  nixReads = [
    "${home}/.cache/nix"
    "${home}/.local/state/nix"
  ];

  # treefmt (what `nix fmt` runs) caches under the macOS-native location, not
  # XDG — missing this is what made `nix fmt` the last command to go green.
  toolchainReads = [
    "${home}/code"
    "${home}/.cache"
    "${home}/.config"
    "${home}/.local"
    "${home}/Library/Caches"
    "${home}/.gitconfig"
  ];

  # `commit.gpgSign = true` with `gpg.format = "ssh"` (modules/user/git/git.nix)
  # means denying ~/.ssh outright breaks every commit the agent makes. Allow the
  # signing key and the connection plumbing by name; the other four private keys
  # (claudio-codes, homelab_id_ed25519, id_ed25519, workM137516) stay denied.
  sshSigningReads = [
    "${home}/.ssh/allowed_signers"
    "${home}/.ssh/config"
    "${home}/.ssh/github"
    "${home}/.ssh/github.pub"
    "${home}/.ssh/known_hosts"
  ];

  # Carved back out of the allowRead entries above — reads honour narrower-wins,
  # so a nested deny inside an allowed tree holds. (Writes do NOT work this way:
  # denyWrite beats allowWrite unconditionally, so never pair the two.)
  credentialDenies = [
    "${home}/.aws"
    "${home}/.claude/.credentials.json"
    "${home}/.config/1Password"
    "${home}/.config/gh"
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

    # Without these two the boundary is advisory: Claude may otherwise retry a
    # blocked command unsandboxed, or silently continue if Seatbelt is missing.
    allowUnsandboxedCommands = false;
    failIfUnavailable = true;

    # Sandboxed Bash is already OS-confined, so re-asking per command buys
    # nothing but friction.
    autoAllowBashIfSandboxed = true;

    # Docker and the sandbox do not compose (upstream states this outright).
    # Excluded commands run entirely unwrapped — no Seatbelt, no network fence —
    # so this is a hole in the boundary, not a containment of it.
    excludedCommands = [ "docker" ];

    network = {
      # `nix` talks to its daemon over this socket; without it every nix
      # subcommand fails with "cannot connect to socket".
      allowUnixSockets = [ "/nix/var/nix/daemon-socket/socket" ];
    };

    filesystem = {
      # Reads are allow-everything-by-default upstream, which is how the jail's
      # deny-by-default property was lost. Denying $HOME wholesale and allowing
      # back only what the toolchain needs recovers most of it.
      denyRead = [ home ] ++ credentialDenies;
      allowRead = toolchainReads ++ nixReads ++ sshSigningReads;

      # Writes are already deny-by-default; these are the dirs the toolchain
      # needs to mutate. cwd is writable implicitly and is NOT listed here.
      allowWrite = [
        "${home}/code"
        "${home}/.cache"
        "${home}/.local/state"
        "${home}/Library/Caches"
      ];
    };
  };
}
