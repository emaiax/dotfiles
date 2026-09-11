# The `claude-yolo` profile: no Seatbelt sandbox, no permission prompts, layered over the default profile via
# `--settings` plus `--dangerously-skip-permissions`. See docs/sandbox-notes.md's "claude-yolo" sections.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.home.homeDirectory;
  perms = import ../permissions.nix { inherit home lib; };

  settings = {
    sandbox.enabled = false;
    permissions = perms.claudeCode.credentialDenyOnly;
  };

  settingsFile = (pkgs.formats.json { }).generate "claude-yolo-settings.json" settings;
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "claude-yolo";
      runtimeInputs = [ config.programs.claude-code.package ];
      text = ''
        exec claude --dangerously-skip-permissions --settings ${settingsFile} "$@"
      '';
    })
  ];
}
