# The `claudio-thebot` profile: publishes into claudio-core, layered over the base settings via `--settings`
# (see #121). Adds `--add-dir` since it can be invoked from anywhere, not just from inside the target repos,
# and Read/Edit/Write only see the launch cwd by default. `--plugin-dir` loads claudio-core's own skills/ on
# top of the operator's base CLAUDIO persona, namespaced as `claudio-core:<skill-name>` (claudio-core carries
# a `.claude-plugin/plugin.json` manifest for exactly this).
#
# `--add-dir` does NOT auto-load a CLAUDE.md from the directories it grants, despite what `claude --bare
# --help` implies (verified empirically: a live session had no knowledge of claudio-core's AGENTS.md content
# until this flag was added). `--append-system-prompt-file` is the one that actually merges it in.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  home = config.home.homeDirectory;
  profile = "claudio-thebot";

  claudioCore = "${home}/code/${profile}/claudio-core";
  claudioState = ".local/share/${profile}";

  identityBinDir = "${claudioState}/identity-bin";
  fjIdentityHome = "${claudioState}/fj-identity";
  ghIdentityConfigDir = "${claudioState}/gh-identity";

  fjHost = "forgejo.emx.casa";
  fjTokenPath = config.sops.secrets."claudio-thebot-fj-token".path;
  ghTokenPath = config.sops.secrets."claudio-thebot-gh-token".path;

  # `active` is the full shell body to run under CLAUDIO_THEBOT_SESSION (must exec, not just set env), not
  # just a command prefix, so wrappers that need extra setup (fj, gh) share this gate instead of hand-rolling
  # their own copy of it.
  mkIdentityWrapper =
    {
      name,
      active,
      passive,
    }:
    pkgs.writeShellScript name ''
      set -euo pipefail
      if [[ -n "''${CLAUDIO_THEBOT_SESSION:-}" ]]; then
        ${active}
      else
        exec ${passive} "$@"
      fi
    '';

  settings = {
    # Presence rules are soft_deny, not permissions.deny, precisely so this profile can carve itself an
    # exception here: a permissions deny can't be overridden from a higher layer.
    autoMode.allow = [
      "$defaults"

      ''
        This session is a publishing agent working in ${claudioCore} and posting under its own bot identity rather than the operator's.
        Opening pull requests, creating and editing issues, and commenting on them are its purpose there, so the rule reserving published
        presence to the operator does not apply to that repository. It still applies everywhere else.
      ''
    ];
  };

  settingsFile = (pkgs.formats.json { }).generate "claudio-thebot-settings.json" settings;

  claudioCoreArgs = ''
    --add-dir "${claudioCore}" \
    --plugin-dir "${claudioCore}" \
    --append-system-prompt-file "${claudioCore}/AGENTS.md" \
  '';
in
{
  sops.secrets = {
    "claudio-thebot-fj-token" = {
      key = "fj-token";
      sopsFile = ./claudio-thebot.enc.yaml;

    };
    "claudio-thebot-gh-token" = {
      key = "gh-token";
      sopsFile = ./claudio-thebot.enc.yaml;
    };
  };

  home.file = {
    "${claudioState}/git-identity.gitconfig".text = ''
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
        active = ''exec ${pkgs.git}/bin/git -c include.path="${home}/${claudioState}/git-identity.gitconfig" "$@"'';
        passive = "${pkgs.git}/bin/git";
      };
      executable = true;
    };

    # fj has no env-var token override (unlike gh's GH_TOKEN), so the only non-interactive way in is
    # `fj auth add-token < token-file` against its isolated $HOME. Bootstraps itself from the sops secret on
    # first use instead of a home.activation script, since sops-nix decrypts secrets via an async LaunchAgent
    # on Darwin (see modules/user/sops) and an activation-time write would race it. The marker file is the
    # idempotency check on every call after the first; no fallback re-check against `fj auth list` if the
    # marker goes missing without the auth store also going missing, since they live in the same directory
    # and are wiped together in practice. Claude Code fires parallel Bash tool calls, so two `fj` invocations
    # can both reach this bootstrap before the marker exists; `mkdir` is atomic and needs no extra package, so
    # it doubles as the lock serializing them.
    "${identityBinDir}/fj" = {
      source = mkIdentityWrapper {
        name = "claudio-identity-fj";
        active = ''
          export HOME="${home}/${fjIdentityHome}"
          marker="$HOME/.claudio-thebot-fj-authenticated"
          if [[ ! -e "$marker" ]]; then
            lockdir="$HOME/.claudio-thebot-fj-auth.lock"
            trap 'rmdir "$lockdir" 2>/dev/null || true' EXIT
            until mkdir "$lockdir" 2>/dev/null; do sleep 0.1; done
            if [[ ! -e "$marker" ]]; then
              if [[ ! -s "${fjTokenPath}" ]]; then
                echo "claudio-identity-fj: token not ready at ${fjTokenPath} (sops-nix decrypt still pending?)" >&2
                exit 1
              fi
              ${pkgs.forgejo-cli}/bin/fj auth add-token --host "${fjHost}" < "${fjTokenPath}"
              touch "$marker"
            fi
            rmdir "$lockdir"
            trap - EXIT
          fi
          exec ${pkgs.forgejo-cli}/bin/fj "$@"
        '';
        passive = "${pkgs.forgejo-cli}/bin/fj";
      };
      executable = true;
    };

    # gh reads GH_TOKEN straight from the environment (its own documented headless-auth path), so unlike fj
    # nothing needs to be persisted to gh's own config store. The token is exported fresh on every call.
    # Fails loudly instead of exporting an empty GH_TOKEN if sops-nix's secret hasn't decrypted yet (same
    # async-LaunchAgent race as fj's bootstrap above).
    "${identityBinDir}/gh" = {
      source = mkIdentityWrapper {
        name = "claudio-identity-gh";
        active = ''
          if [[ ! -s "${ghTokenPath}" ]]; then
            echo "claudio-identity-gh: token not ready at ${ghTokenPath} (sops-nix decrypt still pending?)" >&2
            exit 1
          fi
          exec env GH_CONFIG_DIR="${home}/${ghIdentityConfigDir}" GH_TOKEN="$(<"${ghTokenPath}")" ${pkgs.gh}/bin/gh "$@"
        '';
        passive = "${pkgs.gh}/bin/gh";
      };
      executable = true;
    };
  };

  home.packages = [
    (pkgs.writeShellApplication {
      runtimeInputs = [ config.programs.claude-code.package ];

      name = "claudio-thebot";
      text = ''
        export PATH="${home}/${identityBinDir}:$PATH"

        # No runtime check here can catch a devshell shadowing git/fj/gh ahead of identity-bin: that
        # shadowing, if it happens, happens in a later Bash tool call the running claude session makes, in a
        # separate shell invocation, after this script has already exec'd claude. A `command -v` check right
        # here would only confirm the PATH prepend on the line above took effect in this process, which is
        # guaranteed by construction and proves nothing about later calls. Known limitation, not enforced
        # anywhere: a target repo that sets CLAUDIO_THEBOT_SESSION=1 itself (e.g. its own
        # .claude/settings.json), bypassing this launcher, must independently put identity-bin ahead on its
        # own PATH.
        exec env CLAUDIO_THEBOT_SESSION=1 claude --settings ${settingsFile} ${claudioCoreArgs} "$@"
      '';
    })
  ];
}
