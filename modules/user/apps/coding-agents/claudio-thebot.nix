# The `claudio-thebot` profile: publishes into claudio-core (see issue #121).
#
# Same layering as claudio.nix — `--settings` on top of the default sandbox, so
# credential denies and gates are inherited rather than restated.
#
# Unlike `claudio`, the write target lives INSIDE ~/code, which the default
# layer already grants. denyWrite beats allowWrite without respecting nesting,
# so denying ~/code here would kill the write target too — meaning this profile
# cannot narrow the inherited ~/code grant the way claudio narrows it. Writes
# are therefore scoped by intent, not by the sandbox. See the PR for why that
# is accepted rather than worked around.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  home = config.home.homeDirectory;

  # The source material the bot works from. Its AGENTS.md does not exist yet;
  # pointing at it is harmless — a path that does not exist is inert in both
  # the sandbox rules and the memory loader, verified live.
  contextRepo = "${home}/code/claudio";

  # Where it publishes: github.com/claudio-thebot/claudio-core.
  publishTarget = "${home}/code/claudio-thebot/claudio-core";

  reads = [
    contextRepo
    publishTarget
  ];

  settings = {
    # The whole reason the presence rules live in `soft_deny` rather than
    # `permissions.deny`: this is the one profile whose job is publishing, and
    # a permissions deny could not be carved out for it from here — a
    # higher-precedence layer cannot loosen a lower one.
    #
    # Scoped to claudio-core specifically, and to the bot's own identity, so it
    # does not become a general licence to post as the operator.
    autoMode.allow = [
      "$defaults"

      "This session is the claudio-thebot publishing agent, working in ~/code/claudio-thebot/claudio-core, whose remote is github.com/claudio-thebot/claudio-core. Publishing there — opening pull requests, creating and editing issues, and commenting on them — is this agent's own purpose and posts under the claudio-thebot identity rather than the operator's, so it is exempt from the rule reserving published presence to the operator. That exemption covers this repository only; anywhere else the rule still applies."
    ];

    sandbox = {
      filesystem = {
        allowRead = reads;
        allowWrite = [ publishTarget ];
      };

      # Network is deliberately unrestricted, same as claudio: the boundary that
      # matters for a publishing bot is which *actions* it may take, not which
      # hosts it may reach. An allowlist here would only break fetching.
    };
  };

  settingsFile = (pkgs.formats.json { }).generate "claudio-thebot-settings.json" settings;

  # Grants the Read/Edit tools what the sandbox grants Bash — both renders are
  # needed since Read/Edit bypass the sandbox entirely.
  addDirArgs = lib.concatMapStringsSep " " (d: ''--add-dir "${d}"'') reads;
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "claudio-thebot";
      runtimeInputs = [ config.programs.claude-code.package ];
      text = ''
        # Dedicated empty cwd, for the same reason as claudio: cwd is writable
        # by default, so launching from the publish target or from $HOME would
        # widen the write scope without any visible sign.
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
