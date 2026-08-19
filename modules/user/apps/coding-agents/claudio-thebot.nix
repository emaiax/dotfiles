# The `claudio-thebot` profile: publishes into claudio-core, layered over claude-sandbox.nix via `--settings` (see #121).
#
# The write target sits inside ~/code, which the default layer already grants. denyWrite ignores nesting, so denying ~/code here would kill the target with it. Writes are scoped by intent rather than by the sandbox.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  home = config.home.homeDirectory;

  # AGENTS.md here does not exist yet. A path that does not exist is inert.
  contextRepo = "${home}/code/claudio";
  publishTarget = "${home}/code/claudio-thebot/claudio-core";

  reads = [
    contextRepo
    publishTarget
  ];

  settings = {
    # Why the presence rules are soft_deny rather than permissions.deny: this profile has to be able to override them, and a permissions deny cannot be carved out from a higher layer. Scoped to one repo so it stays an exception.
    autoMode.allow = [
      "$defaults"

      "This session is a publishing agent working in ${publishTarget} and posting under its own bot identity rather than the operator's. Opening pull requests, creating and editing issues, and commenting on them are its purpose there, so the rule reserving published presence to the operator does not apply to that repository. It still applies everywhere else."
    ];

    sandbox.filesystem = {
      allowRead = reads;
      allowWrite = [ publishTarget ];
    };
  };

  settingsFile = (pkgs.formats.json { }).generate "claudio-thebot-settings.json" settings;

  # Read/Edit bypass the sandbox, so the same paths have to be granted twice.
  addDirArgs = lib.concatMapStringsSep " " (d: ''--add-dir "${d}"'') reads;
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "claudio-thebot";
      runtimeInputs = [ config.programs.claude-code.package ];
      text = ''
        # cwd is always writable and nothing here overrides that, so launch from an empty dir rather than wherever the command was typed.
        scratch="''${XDG_CACHE_HOME:-$HOME/.cache}/claudio-thebot/cwd"
        mkdir -p "$scratch"
        cd "$scratch"

        exec claude \
          --settings ${settingsFile} \
          ${addDirArgs} \
          "$@"
      '';
    })
  ];
}
