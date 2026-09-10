# The `claude-yolo` profile: no Seatbelt sandbox, no permission prompts, layered over the default profile via
# `--settings` plus `--dangerously-skip-permissions`. The shared base (claude-code/default.nix) defines no
# permissions at all (2026-09-10): this profile explicitly opts back into just the credential-file deny rules
# every other bundle carries unconditionally (perms.claudeCode.credentialDenyOnly), everything else stays
# traded away same as before. See sandbox-notes.md for what every trade-off here costs.
#
# First interactive run shows a one-time disclaimer dialog (accepted state saved to user settings, asked once
# per machine); until then a backgrounded run (--bg) is refused outright. Accept it interactively before ever
# backgrounding one.
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
