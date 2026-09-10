# Google's Antigravity agent CLI (binary name: agy). No home-manager module exists upstream for it,
# unlike Claude Code/opencode, so this hand-rolls the two pieces such a module would cover.
{
  config,
  dotfilesPath,
  lib,
  pkgs,
  ...
}:
let
  settingsPath = "${config.home.homeDirectory}/.gemini/antigravity-cli/settings.json";
  trackedSettings = "${dotfilesPath}/modules/user/apps/antigravity-cli/settings.json";
in
{
  home.packages = [ pkgs.antigravity-cli ];

  # agy rewrites this file live (trustedWorkspaces etc), so seed once if missing; a later diff only
  # warns, never re-copies. Sync it back into the tracked file by hand when that's worth keeping.
  home.activation.antigravityCliSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ ! -e "${settingsPath}" ]]; then
      install -Dm600 "${trackedSettings}" "${settingsPath}"
    elif ! diff -q "${trackedSettings}" "${settingsPath}" >/dev/null; then
      echo "[antigravity-cli] live settings differ from the tracked seed: ${settingsPath}" >&2
    fi
  '';
}
