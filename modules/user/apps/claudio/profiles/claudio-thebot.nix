# The `claudio-thebot` profile: publishes into claudio-core, layered over the base settings via `--settings`.
# Adds `--add-dir` since it can be invoked from anywhere, not just from inside the target repos,
# and Read/Edit/Write only see the launch cwd by default. `--plugin-dir` loads claudio-core's own skills/ on
# top of the operator's base CLAUDIO persona, namespaced as `claudio-core:<skill-name>` (claudio-core carries
# a `.claude-plugin/plugin.json` manifest for exactly this).
#
# `--add-dir` does NOT auto-load a CLAUDE.md from the directories it grants, despite what `claude --bare
# --help` implies (verified empirically: a live session had no knowledge of claudio-core's AGENTS.md content
# until this flag was added). `--append-system-prompt-file` is the one that actually merges it in.
#
# This profile is yolo-only (2026-09-10 consolidation): `--dangerously-skip-permissions`, zero permissions
# (perms.claudeCode.yolo, the literal empty object), sandbox disabled. There used to be a second, gated
# variant plus a separate `claudio-thebot-yolo` binary; both are gone. This is the homelab-scoped AFK
# publishing agent, not a profile meant to still ask anything — see AGENTS.md's Autonomy & Approval section.
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

  # bypassPermissions skips auto mode entirely, so there is no autoMode carve-out to declare here (the old
  # bot-identity presence exception only mattered for the gated variant this profile no longer has).
  # perms.claudeCode.yolo is the literal empty object: zero ask, zero deny, zero allow (permissions.nix,
  # 2026-09-10). A base-inherited `ask` on `git push` used to fire here even under bypassPermissions (verified
  # empirically 2026-09-10); the fix was removing that base-level ask entirely, not allowlisting around it.
  settingsFile = (pkgs.formats.json { }).generate "claudio-thebot-settings.json" {
    sandbox.enabled = false;
    permissions = perms.claudeCode.yolo;
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
    # no sandbox, no permission prompts
    (pkgs.writeShellApplication {
      runtimeInputs = [ config.programs.claude-code.package ];

      name = "claudio-thebot";
      text = ''
        export PATH="${home}/${identityBinDir}:$PATH"

        exec env CLAUDIO_THEBOT_SESSION=1 claude \
          --dangerously-skip-permissions \
          --settings ${settingsFile} \
          ${claudioCoreArgs} \
          "$@"
      '';
    })
  ];
}
