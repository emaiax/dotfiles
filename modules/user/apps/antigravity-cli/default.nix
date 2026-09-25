# Google's Antigravity agent CLI (binary name: agy).
# Home-manager provides programs.antigravity-cli, but writes settings.json as a read-only store symlink.
# agy replaces its settings.json wholesale on save (0600 file), so any symlink gets broken on first write.
# We disable the upstream home.file symlink and manage settings.json via an activation smart-merge.
{
  config,
  dotfilesPath ? "${config.home.homeDirectory}/code/dotfiles",
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.antigravity-cli;
  settingsPath = "${config.home.homeDirectory}/.gemini/antigravity-cli/settings.json";
  trackedSettings = "${dotfilesPath}/modules/user/apps/antigravity-cli/settings.json";

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
      colorScheme = lib.mkDefault "tokyo night";
      enableTelemetry = lib.mkDefault false;
      verbosity = lib.mkDefault "low";
    };
  };

  # Disable home-manager's store symlink so it doesn't collide with agy's live runtime file
  home.file.".gemini/antigravity-cli/settings.json".enable = false;

  # Smart merge on just switch:
  # 1. Enforce Nix-declared settings (theme, telemetry, verbosity).
  # 2. Preserve live runtime state (trustedWorkspaces).
  # 3. Union declared approvals with live ad-hoc approvals.
  # 4. Sync the tracked seed file in dotfiles so version control reflects declarative state.
  home.activation.antigravityCliSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    liveSettings="${settingsPath}"
    tracked="${trackedSettings}"

    # Update tracked seed file in dotfiles if it exists and changed
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
            allow: ((($live.permissions.allow // []) + ($nix.permissions.allow // [])) | unique)
          }
        }
      ' "$liveSettings" "${generatedSettingsJson}" > "$tmp"
      install -Dm600 "$tmp" "$liveSettings"
      rm -f "$tmp"
    fi
  '';
}
