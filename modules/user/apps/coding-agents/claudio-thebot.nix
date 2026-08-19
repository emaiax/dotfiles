# The `claudio-thebot` profile: publishes into claudio-core, layered over claude-sandbox.nix via `--settings` (see #121).
#
# Read/write in ~/code is already inherited from the default layer, so this profile adds none of its own. What it does add is `--add-dir`: Read/Edit/Write only see the launch cwd by default, and this can be invoked from anywhere, not just from inside the target repos.
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
  };

  settingsFile = (pkgs.formats.json { }).generate "claudio-thebot-settings.json" settings;

  # Read/Edit/Write only see the launch cwd by default, and this profile can be invoked from anywhere, so the context and publish repos need to be granted explicitly.
  addDirArgs = lib.concatMapStringsSep " " (d: ''--add-dir "${d}"'') reads;
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "claudio-thebot";
      runtimeInputs = [ config.programs.claude-code.package ];
      text = ''
        exec claude \
          --settings ${settingsFile} \
          ${addDirArgs} \
          "$@"
      '';
    })
  ];
}
