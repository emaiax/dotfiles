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
    sandbox = {
      filesystem = {
        allowRead = reads;
        allowWrite = [ publishTarget ];
      };

      network = {
        # Narrow allowlist rather than claudio's total denial: claudio-core is a
        # GitHub remote, so fetch/status need to resolve it. Publishing still
        # goes through the gates — `git push` is denied and `git commit` asks,
        # from gates.nix — so reachability here is not permission to publish.
        #
        # Set directly rather than via a WebFetch allow rule: those leak into
        # this same allowlist, so keeping them separate means the network scope
        # stays legible in one place.
        allowedDomains = [ "github.com" ];
        strictAllowlist = true;
      };
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
