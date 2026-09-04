# claudio-thebot identity wrappers for git, fj, and gh.
#
# CLAUDIO_THEBOT_SESSION is exported per-repo, via that repo's own .claude/settings.json
# env block (see dudumox's docs/superpowers/specs/2026-08-16-emaiax-personal-pat-and-agent-identity-separation-design.md,
# Part 1, which introduced the variable for fj alone). Installing these wrappers once, here,
# means any repo that already opts a Claude Code session into that variable gets claudio-thebot
# identity for git/fj/gh without touching that repo's own flake or shell config.
#
# Each wrapper checks the variable at call time, not at shell-init time: a shell that exists
# before a Claude Code session ever attaches to it (a pre-opened terminal, a direnv-loaded
# shell) would otherwise never re-evaluate the check and silently keep passing through as the
# human, no matter what later sets the variable in a subprocess. Checking on every invocation
# closes that race.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  identityBinDir = ".local/share/claudio/identity-bin";
  gitIdentityConfigPath = "${config.home.homeDirectory}/.claudio-git-identity.gitconfig";
  fjIdentityHome = "${config.home.homeDirectory}/.claudio-fj-identity";
  ghIdentityConfigDir = "${config.home.homeDirectory}/.claudio-gh-identity";

  mkIdentityWrapper =
    {
      name,
      activeExec,
      passiveExec,
    }:
    pkgs.writeShellScript name ''
      if [[ -n "''${CLAUDIO_THEBOT_SESSION:-}" ]]; then
        exec ${activeExec} "$@"
      else
        exec ${passiveExec} "$@"
      fi
    '';
in
{
  # Prepended ahead of the home-manager profile's own git/fj/gh, so a plain interactive shell
  # picks these up by name. A devshell that lists git/fj/gh in its own nativeBuildInputs can
  # still shadow this — verify per-repo before relying on it there.
  home.sessionPath = [ "${config.home.homeDirectory}/${identityBinDir}" ];

  home.file = {
    # A standalone fragment, not five separate `-c` flags in the wrapper: readable on its own
    # (`cat ~/.claudio-git-identity.gitconfig`) regardless of how many settings the identity
    # ends up needing, verified this session that `-c include.path=` layers it in correctly
    # without replacing the rest of ~/.gitconfig (aliases, pull.rebase, etc. still apply).
    ".claudio-git-identity.gitconfig".text = ''
      [user]
      	name = claudio-thebot
      	email = claudio-thebot@users.noreply.github.com
      	signingkey = ~/.ssh/claudio-codes.pub

      [gpg]
      	format = ssh

      [commit]
      	gpgsign = true
    '';

    "${identityBinDir}/git" = {
      source = mkIdentityWrapper {
        name = "claudio-identity-git";
        activeExec = "${pkgs.git}/bin/git -c include.path=${gitIdentityConfigPath}";
        passiveExec = "${pkgs.git}/bin/git";
      };
      executable = true;
    };

    # Reuses the identity store dudumox's own fj design already bootstraps
    # (~/.claudio-fj-identity) — fj's credential store is keyed by $HOME, not by account,
    # so redirecting HOME is the only way to switch which account it authenticates as.
    "${identityBinDir}/fj" = {
      source = mkIdentityWrapper {
        name = "claudio-identity-fj";
        activeExec = "env HOME=${fjIdentityHome} ${pkgs.forgejo-cli}/bin/fj";
        passiveExec = "${pkgs.forgejo-cli}/bin/fj";
      };
      executable = true;
    };

    # Structure only: activating this needs a claudio-thebot GitHub account and token, which
    # don't exist yet (see dotfiles#157). Until ~/.claudio-gh-identity is bootstrapped with a
    # logged-in token, this exec's identically to the real gh even when CLAUDIO_THEBOT_SESSION
    # is set, since GH_CONFIG_DIR just points gh at an empty, unauthenticated config dir.
    "${identityBinDir}/gh" = {
      source = mkIdentityWrapper {
        name = "claudio-identity-gh";
        activeExec = "env GH_CONFIG_DIR=${ghIdentityConfigDir} ${pkgs.gh}/bin/gh";
        passiveExec = "${pkgs.gh}/bin/gh";
      };
      executable = true;
    };
  };
}
