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
    # on Darwin (see modules/user/sops) and an activation-time write would race it. The marker file (not
    # `fj auth list`) is the fast-path idempotency check on every call after the first; `fj auth list | grep`
    # only runs once per fresh isolated $HOME, to self-heal if it was ever wiped without the marker surviving
    # (they live in the same directory, so in practice they're wiped together).
    "${identityBinDir}/fj" = {
      source = mkIdentityWrapper {
        name = "claudio-identity-fj";
        active = ''
          export HOME="${home}/${fjIdentityHome}"
          marker="$HOME/.claudio-thebot-fj-authenticated"
          if [[ ! -e "$marker" ]]; then
            if ! ${pkgs.forgejo-cli}/bin/fj auth list 2>/dev/null | grep -qx "${fjHost}"; then
              if [[ ! -s "${fjTokenPath}" ]]; then
                echo "claudio-identity-fj: token not ready at ${fjTokenPath} (sops-nix decrypt still pending?)" >&2
                exit 1
              fi
              ${pkgs.forgejo-cli}/bin/fj auth add-token --host "${fjHost}" < "${fjTokenPath}"
            fi
            touch "$marker"
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
          exec env GH_CONFIG_DIR="${home}/${ghIdentityConfigDir}" GH_TOKEN="$(cat "${ghTokenPath}")" ${pkgs.gh}/bin/gh "$@"
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

        # Catches a shell that shadows git/fj/gh ahead of identity-bin (e.g. a devshell listing them in its
        # own nativeBuildInputs): fail loudly instead of silently publishing as the operator for the whole
        # session. Does NOT catch a session that sets CLAUDIO_THEBOT_SESSION directly (e.g. a target repo's
        # own .claude/settings.json) without going through this launcher — that path never runs this check,
        # since it never runs this script at all; it must separately put identity-bin ahead on its own PATH.
        for bin in git fj gh; do
          resolved="$(command -v "$bin")"
          case "$resolved" in
            "${home}/${identityBinDir}"/*) ;;
            *)
              echo "claudio-thebot: $bin resolved to $resolved, not the identity wrapper — refusing to start under the wrong identity" >&2
              exit 1
              ;;
          esac
        done

        exec env CLAUDIO_THEBOT_SESSION=1 claude --settings ${settingsFile} ${claudioCoreArgs} "$@"
      '';
    })
  ];
}
