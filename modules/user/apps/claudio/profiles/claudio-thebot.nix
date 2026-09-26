# The `claudio-thebot` profile: publishes into claudio-core, layered over the base settings via `--settings`.
# See docs/sandbox-notes.md for the --add-dir/--plugin-dir wiring and this profile's yolo-only consolidation.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  home = config.home.homeDirectory;
  profile = "claudio-thebot";
  claudioCfg = config.programs.claudio;

  perms = import ../permissions.nix {
    inherit home lib;
    inherit (claudioCfg) permissions;
  };

  claudioCore = "${home}/code/${profile}/claudio-core";
  claudioState = ".local/share/${profile}";

  identityBinDir = "${claudioState}/identity-bin";
  fjIdentityHome = "${claudioState}/fj-identity";
  ghIdentityConfigDir = "${claudioState}/gh-identity";

  fjHost = "forgejo.emx.casa";
  fjTokenPath = config.sops.secrets."claudio-thebot-fj-token".path;
  ghTokenPath = config.sops.secrets."claudio-thebot-gh-token".path;

  # `active` is the full shell body run under CLAUDIO_THEBOT_SESSION (must exec, not just set env), so wrappers
  # needing extra setup (fj, gh) share this gate instead of hand-rolling their own copy.
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

  # bypassPermissions skips auto mode entirely, no carve-out needed here. Empty object:
  # docs/sandbox-notes.md's "claude-yolo: what it actually trades away" section has the history.
  settingsFile = (pkgs.formats.json { }).generate "claudio-thebot-settings.json" {
    sandbox.enabled = false;
    permissions = { };
  };

  claudioCoreArgs = ''
    --add-dir "${claudioCore}" \
    --plugin-dir "${claudioCore}" \
    --append-system-prompt-file "${claudioCore}/AGENTS.md" \
  '';

  claudioCoreArgsAgy = ''
    --add-dir "${claudioCore}" \
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
      runtimeInputs = [
        config.programs.claude-code.package
        config.programs.antigravity-cli.package
        config.programs.opencode.package
      ];

      name = "claudio-thebot";
      text = ''
        export PATH="${home}/${identityBinDir}:$PATH"

        default_backend="${config.programs.claudio.backend}"
        backend="$default_backend"

        if [[ -n "''${CLAUDIO_BACKEND:-}" ]]; then
          backend="$CLAUDIO_BACKEND"
        fi

        if [[ $# -gt 0 ]]; then
          case "$1" in
            --agy)
              backend="agy"
              shift
              ;;
            --claude|--claude-code)
              backend="claude-code"
              shift
              ;;
            --opencode)
              backend="opencode"
              shift
              ;;
            --backend|-b)
              if [[ $# -lt 2 ]]; then
                echo "claudio-thebot: missing argument for $1" >&2
                exit 1
              fi
              backend="$2"
              shift 2
              ;;
            --backend=*)
              backend="''${1#*=}"
              shift
              ;;
          esac
        fi

        case "$backend" in
          agy)
            exec env CLAUDIO_THEBOT_SESSION=1 CLAUDIO_DANGEROUSLY_SKIP_PERMISSIONS=1 agy \
              --dangerously-skip-permissions \
              ${claudioCoreArgsAgy} \
              "$@"
            ;;
          claude-code)
            exec env CLAUDIO_THEBOT_SESSION=1 claude \
              --dangerously-skip-permissions \
              --settings ${settingsFile} \
              ${claudioCoreArgs} \
              "$@"
            ;;
          opencode)
            exec env CLAUDIO_THEBOT_SESSION=1 opencode \
              --auto \
              "$@"
            ;;
          *)
            echo "claudio-thebot: unknown backend '$backend' (supported: agy, claude-code, opencode)" >&2
            exit 1
            ;;
        esac
      '';
    })
  ];
}
