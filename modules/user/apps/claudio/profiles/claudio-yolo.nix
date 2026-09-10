# The `claude-yolo` profile: no Seatbelt sandbox, no permission prompts, layered over the default profile via
# `--settings` plus `--dangerously-skip-permissions`. Its permissions come from the base, hardDeny = false,
# unlike claudio/claudio-thebot; see sandbox-notes.md for what every trade-off here costs.
#
# First interactive run shows a one-time disclaimer dialog (accepted state saved to user settings, asked once
# per machine); until then a backgrounded run (--bg) is refused outright. Accept it interactively before ever
# backgrounding one.
{
  config,
  pkgs,
  ...
}:
let
  settings = {
    sandbox.enabled = false;
  };

  settingsFile = (pkgs.formats.json { }).generate "claude-yolo-settings.json" settings;
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "claude-yolo";
      runtimeInputs = [ pkgs.claude-code ];
      text = ''
        exec claude --dangerously-skip-permissions --settings ${settingsFile} "$@"
      '';
    })
  ];
}
