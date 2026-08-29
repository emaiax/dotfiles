# The `claudio-thebot` profile: publishes into claudio-core, layered over the base settings via `--settings`
# (see #121). Adds `--add-dir` since it can be invoked from anywhere, not just from inside the target repos,
# and Read/Edit/Write only see the launch cwd by default. `--plugin-dir` loads claudio-core's own skills/ on
# top of the operator's base CLAUDIO persona, namespaced as `claudio-core:<skill-name>` — claudio-core carries
# a `.claude-plugin/plugin.json` manifest for exactly this.
#
# `--add-dir` does NOT auto-load a CLAUDE.md from the directories it grants, despite what `claude --bare
# --help` implies (verified empirically: a live session had no knowledge of claudio-core's AGENTS.md content
# until this flag was added). `--append-system-prompt-file` is the one that actually merges it in.
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
    # Presence rules are soft_deny, not permissions.deny, precisely so this profile can carve itself an
    # exception here: a permissions deny can't be overridden from a higher layer.
    autoMode.allow = [
      "$defaults"

      "This session is a publishing agent working in ${publishTarget} and posting under its own bot identity rather than the operator's. Opening pull requests, creating and editing issues, and commenting on them are its purpose there, so the rule reserving published presence to the operator does not apply to that repository. It still applies everywhere else."
    ];
  };

  settingsFile = (pkgs.formats.json { }).generate "claudio-thebot-settings.json" settings;

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
          --plugin-dir "${publishTarget}" \
          --append-system-prompt-file "${publishTarget}/AGENTS.md" \
          "$@"
      '';
    })
  ];
}
