# The `claude-yolo` profile: no Seatbelt sandbox, no permission prompts, layered over the default profile via `--settings` (see #121) plus `--dangerously-skip-permissions`. deny rules still hold even here — see ../docs/sandbox-notes.md for what this trades away and why.
#
# First interactive run shows a one-time disclaimer dialog (accepted state saved to user settings, asked once per machine); until then a backgrounded run (--bg) is refused outright — same gotcha as #93. Accept it interactively before ever backgrounding one.
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
      runtimeInputs = [ config.programs.claude-code.package ];
      text = ''
        exec claude --dangerously-skip-permissions --settings ${settingsFile} "$@"
      '';
    })
  ];
}
