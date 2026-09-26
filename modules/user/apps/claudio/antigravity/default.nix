# Antigravity CLI (agy) integration for Claudio:
# Lifecycle management, settings smart-merge, security hooks, and global customizations.
{
  claudioPath,
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.home.homeDirectory;
  claudioCfg = config.programs.claudio;
  perms = import ../permissions.nix {
    inherit home lib;
    inherit (claudioCfg) permissions;
  };

  policyJson = (pkgs.formats.json { }).generate "claudio-policy.json" perms.policy;

  hooksConfig = {
    claudio-safety-and-rtk = {
      PreToolUse = [
        {
          matcher = "run_command";
          hooks = [
            {
              type = "command";
              command = ''bash "${claudioPath}/hooks/antigravity-hook.sh" "${policyJson}"'';
            }
          ];
        }
        {
          matcher = "view_file|read_file|write_to_file|replace_file_content";
          hooks = [
            {
              type = "command";
              command = ''bash "${claudioPath}/hooks/antigravity-hook.sh" "${policyJson}"'';
            }
          ];
        }
      ];
    };
  };

  hooksJson = (pkgs.formats.json { }).generate "antigravity-hooks.json" hooksConfig;

  cfg = config.programs.antigravity-cli;
  liveSettingsPath = "${home}/.gemini/antigravity-cli/settings.json";
  trackedSettings = "${claudioPath}/antigravity/settings.json";

  fullSettings = lib.recursiveUpdate (lib.optionalAttrs (cfg.permissions != null) {
    inherit (cfg) permissions;
  }) cfg.settings;

  generatedSettingsJson =
    (pkgs.formats.json { }).generate "antigravity-cli-settings.json"
      fullSettings;
in
{
  programs.antigravity-cli = {
    enable = true;

    settings = {
      altScreenMode = "always";
      colorScheme = "tokyo night";

      artifactReviewPolicy = "agent-decides";
      toolPermission = "request-review";

      enableTelemetry = false;
      showFeedbackSurvey = false;
      verbosity = "low";
    };

    permissions = perms.antigravity.permissions;
  };

  # Disable home-manager's store symlink so it doesn't collide with agy's live runtime file
  home.file.".gemini/antigravity-cli/settings.json".enable = false;

  # Global customizations
  home.file.".gemini/config/AGENTS.md" = {
    source = config.lib.file.mkOutOfStoreSymlink "${claudioPath}/AGENTS.md";
    force = true;
  };

  home.file.".gemini/config/docs" = {
    source = config.lib.file.mkOutOfStoreSymlink "${claudioPath}/docs";
    force = true;
  };

  home.file.".gemini/config/skills" = {
    source = config.lib.file.mkOutOfStoreSymlink "${claudioPath}/skills";
    force = true;
  };

  home.file.".gemini/config/hooks.json" = {
    source = hooksJson;
    force = true;
  };

  # Smart merge on just switch:
  # 1. Enforce Nix-declared settings (theme, telemetry, verbosity).
  # 2. Preserve live runtime state (trustedWorkspaces).
  # 3. Union declared approvals with live ad-hoc approvals.
  # 4. Sync the tracked seed file in claudio/antigravity/settings.json.
  home.activation.antigravityCliSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    liveSettings="${liveSettingsPath}"
    tracked="${trackedSettings}"

    # Update tracked seed file in claudio/antigravity/ if it exists and changed
    if [[ -d "$(dirname "$tracked")" ]] && ! cmp -s "${generatedSettingsJson}" "$tracked" 2>/dev/null; then
      install -Dm644 "${generatedSettingsJson}" "$tracked"
    fi

    if [[ ! -e "$liveSettings" ]]; then
      install -Dm600 "${generatedSettingsJson}" "$liveSettings"
    else
      tmp="$(mktemp)"
      ${pkgs.jq}/bin/jq -s '
        .[0] as $live | .[1] as $nix |
        ($live * $nix) * {
          trustedWorkspaces: ($live.trustedWorkspaces // []),
          permissions: {
            allow: ((($live.permissions.allow // []) + ($nix.permissions.allow // [])) | unique),
            ask: ((($live.permissions.ask // []) + ($nix.permissions.ask // [])) | unique),
            deny: ((($live.permissions.deny // []) + ($nix.permissions.deny // [])) | unique)
          }
        }
      ' "$liveSettings" "${generatedSettingsJson}" > "$tmp"
      install -Dm600 "$tmp" "$liveSettings"
      rm -f "$tmp"
    fi
  '';
}
