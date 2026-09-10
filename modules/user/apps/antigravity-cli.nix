# Google's Antigravity agent CLI (binary name: agy). No home-manager module exists upstream for it,
# unlike Claude Code/opencode, so this hand-rolls the two pieces such a module would cover.
{
  config,
  pkgs,
  ...
}:
let
  # Schema: antigravity.google/docs/cli/settings/. Just the two documented, low-risk keys; the binary
  # also references an undocumented `permissions.allow` key (agy strings), left undeclared for now.
  settings = {
    colorScheme = "dark";
    enableTelemetry = false;
  };

  settingsFile = (pkgs.formats.json { }).generate "antigravity-cli-settings.json" settings;
  settingsPath = "${config.home.homeDirectory}/.gemini/antigravity-cli/settings.json";
in
{
  home.packages = [ pkgs.antigravity-cli ];

  # Plain symlink to the store. Unverified whether agy's own settings panel writes back to this path
  # like Claude Code does; if so this needs claude-code/default.nix's writable-file treatment instead.
  home.file."${settingsPath}".source = settingsFile;
}
