# The `claude-yolo` profile: no Seatbelt sandbox, no permission prompts, layered over the
# default profile via `--settings` (see #121) plus `--dangerously-skip-permissions`.
#
# sandbox.enabled = false is enough on its own — with the sandbox off, none of
# claude-sandbox.nix's other sandbox.* keys (allowMachLookup, filesystem allow/deny, etc.)
# do anything, so this profile doesn't need to replicate any of them.
#
# permissions.ask (git push, rm -rf, git reset --hard, ...) is what actually disappears here:
# --dangerously-skip-permissions (bypassPermissions mode) skips every prompt. permissions.deny
# does NOT disappear — deny rules block in every mode, including bypassPermissions (confirmed
# against code.claude.com/docs/en/permission-modes.md), so gates.nix's denyHard (gh/fj pr
# merge, gh/fj release) and claude-code.nix's credentialDenyRules (Read/Edit on credential
# paths) still hold even under this profile. Sandbox and permission-bypass are independent
# axes (code.claude.com/docs/en/sandboxing.md): disabling one does not disable the other,
# hence needing both here.
#
# The official docs describe bypassPermissions as meant for an isolated container/VM, not a
# trusted host machine (code.claude.com/docs/en/permission-modes.md) — this runs it on the
# host anyway, deliberately. With no sandbox and no ask, the global CLAUDE.md hard rules
# (never push/commit/destroy without approval, never touch main) have no harness backstop
# left under this profile besides denyHard/credentialDenyRules above; they hold only as long
# as the model chooses to follow them. Use this profile only when that trade-off is wanted
# for that session, not as a default.
#
# First interactive run shows a one-time disclaimer dialog (accepted state is saved to user
# settings, so it's asked only once per machine). Until accepted, a backgrounded run
# (--bg) is refused outright — same gotcha as #93. Accept it via a plain interactive
# `claude-yolo` invocation before ever trying to background one.
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
