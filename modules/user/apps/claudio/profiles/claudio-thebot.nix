# The `claudio-thebot` profile: publishes into claudio-core, layered over the base settings via `--settings`.
# Adds `--add-dir` since it can be invoked from anywhere, not just from inside the target repos,
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

  perms = import ../permissions.nix { inherit home lib; };

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

    # This is an "auto" profile (not the yolo one below): opts back into permissions.nix's `hardDenyRules`.
    # See the comment above `denyHard` in permissions.nix's `policy.commands` for why this is opt-in.
    permissions.deny = perms.hardDenyRules;
  };

  settingsFile = (pkgs.formats.json { }).generate "claudio-thebot-settings.json" settings;

  # bypassPermissions skips auto mode entirely. This profile also doesn't opt into `hardDenyRules`: merge
  # and release approval here comes from a real PR review instead (see sandbox-notes.md's `claude-yolo` note).
  yoloSettingsFile = (pkgs.formats.json { }).generate "claudio-thebot-yolo-settings.json" {
    sandbox.enabled = false;
  };

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
      runtimeInputs = [ pkgs.claude-code ];

      name = "claudio-thebot";
      text = ''
        export PATH="${home}/${identityBinDir}:$PATH"

        exec env CLAUDIO_THEBOT_SESSION=1 claude \
          --settings ${settingsFile} \
          ${claudioCoreArgs} \
          "$@"
      '';
    })

    # no sandbox, no permission prompts
    (pkgs.writeShellApplication {
      runtimeInputs = [ pkgs.claude-code ];

      name = "claudio-thebot-yolo";
      text = ''
        export PATH="${home}/${identityBinDir}:$PATH"

        exec env CLAUDIO_THEBOT_SESSION=1 claude \
          --dangerously-skip-permissions \
          --settings ${yoloSettingsFile} \
          ${claudioCoreArgs} \
          "$@"
      '';
    })
  ];
}
