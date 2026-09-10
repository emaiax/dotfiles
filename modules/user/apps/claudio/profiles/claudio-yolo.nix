# The `claude-yolo` profile: no Seatbelt sandbox, no permission prompts, layered over the default profile via
# `--settings` (see #121) plus `--dangerously-skip-permissions`. Credential-file deny rules still hold even
# here (../permissions.nix's `credentialDenyRules`, baked into the shared base). The irreversible-command
# tier (`fj`/`gh` pr merge and release, ../permissions.nix's `hardDenyRules`) does not: this is one of the
# two profiles that deliberately don't opt back into it. See ../docs/sandbox-notes.md for what the sandbox
# and permission-prompt trade-offs cost, and permissions.nix's comment above `denyHard` for the merge/release
# one specifically.
#
# First interactive run shows a one-time disclaimer dialog (accepted state saved to user settings, asked once
# per machine); until then a backgrounded run (--bg) is refused outright, same gotcha as #93. Accept it
# interactively before ever backgrounding one.
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
