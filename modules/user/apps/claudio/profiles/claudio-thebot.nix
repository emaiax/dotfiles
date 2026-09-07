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

  settings = {
    # Presence rules are soft_deny, not permissions.deny, precisely so this profile can carve itself an
    # exception here: a permissions deny can't be overridden from a higher layer.
    autoMode.allow = [
      "$defaults"

      "This session is a publishing agent working in ${claudioCore} and posting under its own bot identity rather than the operator's.
       Opening pull requests, creating and editing issues, and commenting on them are its purpose there, so the rule reserving published
       presence to the operator does not apply to that repository. It still applies everywhere else."
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
        activeExec = "${pkgs.git}/bin/git -c include.path=\"${home}/${claudioState}/git-identity.gitconfig\"";
        passiveExec = "${pkgs.git}/bin/git";
      };
      executable = true;
    };

    # Not a mkIdentityWrapper: fj has no env-var token override (unlike gh's GH_TOKEN), so the only
    # non-interactive way in is `fj auth add-token < token-file` against its isolated $HOME. Bootstraps
    # itself from the sops secret on first use instead of a home.activation script, since sops-nix decrypts
    # secrets via an async LaunchAgent on Darwin (see modules/user/sops) and an activation-time write would
    # race it. `fj auth list` is the idempotency check so re-running this doesn't re-add the token every call.
    "${identityBinDir}/fj" = {
      source = pkgs.writeShellScript "claudio-identity-fj" ''
        set -euo pipefail
        if [[ -n "''${CLAUDIO_THEBOT_SESSION:-}" ]]; then
          export HOME="${home}/${fjIdentityHome}"
          if ! ${pkgs.forgejo-cli}/bin/fj auth list 2>/dev/null | grep -qx "${fjHost}"; then
            if [[ ! -s "${fjTokenPath}" ]]; then
              echo "claudio-identity-fj: token not ready at ${fjTokenPath} (sops-nix decrypt still pending?)" >&2
              exit 1
            fi
            ${pkgs.forgejo-cli}/bin/fj auth add-token --host "${fjHost}" < "${fjTokenPath}"
          fi
          exec ${pkgs.forgejo-cli}/bin/fj "$@"
        else
          exec ${pkgs.forgejo-cli}/bin/fj "$@"
        fi
      '';
      executable = true;
    };

    # gh reads GH_TOKEN straight from the environment (its own documented headless-auth path), so unlike fj
    # nothing needs to be persisted to gh's own config store. The token is exported fresh on every call.
    # Not a mkIdentityWrapper: needs to fail loudly, not export an empty GH_TOKEN, if sops-nix's secret
    # hasn't decrypted yet (same async-LaunchAgent race as fj's bootstrap above).
    "${identityBinDir}/gh" = {
      source = pkgs.writeShellScript "claudio-identity-gh" ''
        set -euo pipefail
        if [[ -n "''${CLAUDIO_THEBOT_SESSION:-}" ]]; then
          if [[ ! -s "${ghTokenPath}" ]]; then
            echo "claudio-identity-gh: token not ready at ${ghTokenPath} (sops-nix decrypt still pending?)" >&2
            exit 1
          fi
          exec env GH_CONFIG_DIR="${home}/${ghIdentityConfigDir}" GH_TOKEN="$(cat "${ghTokenPath}")" ${pkgs.gh}/bin/gh "$@"
        else
          exec ${pkgs.gh}/bin/gh "$@"
        fi
      '';
      executable = true;
    };
  };

  home.packages = [
    (pkgs.writeShellApplication {
      runtimeInputs = [ config.programs.claude-code.package ];

      name = "claudio-thebot";
      text = ''
        export PATH="${home}/${identityBinDir}:$PATH"
        exec env CLAUDIO_THEBOT_SESSION=1 claude --settings ${settingsFile} ${claudioCoreArgs} "$@"
      '';
    })
  ];
}
