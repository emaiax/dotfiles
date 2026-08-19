# The `claudio` profile: Obsidian vault work, no shell network (see issue #121).
#
# Layered on top of the default sandbox (claude-sandbox.nix) via `--settings`,
# which merges rather than replaces — so every credential deny and every gate
# from the default layer still applies here. That is why this file only states
# what differs.
#
# Two hard constraints, both established by live test rather than from docs:
#
#   1. The wrapper MUST launch from a narrow, dedicated cwd. cwd is writable by
#      default, so starting inside ~/Obsidian/emaiax would make the whole vault
#      writable — and `cd "$HOME"` is just as bad, since it hands the agent
#      write access to the entire home directory. Both were verified to defeat
#      the write scope entirely; an empty scratch dir is the only safe choice.
#   2. No `denyWrite` on the vault, deliberately. denyWrite beats allowWrite
#      unconditionally, so denying the vault root would also kill the nested
#      allowWrite — the scope works *because* writes are deny-by-default and
#      only the listed paths are opened. denyWrite IS used below, but only on
#      paths disjoint from the vault, where that precedence is what we want.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  home = config.home.homeDirectory;

  vaults = {
    # Read the whole vault, write only the folder set aside for agent output.
    # Note this reads wider than agent-jail did — the jail mounted two folders
    # and the rest of the vault simply did not exist to the agent. Narrow
    # `read` here if that matters more than convenience.
    personal = rec {
      root = "${home}/Obsidian/emaiax";
      read = [ root ];
      write = [ "${root}/99 - metadata/99.04 - agentic" ];
    };

    # Currently a folder inside the personal vault; becomes its own vault soon.
    # Anchored on its own `root` precisely so that migration is a one-line path
    # change here and nothing else moves.
    work = rec {
      root = "${home}/Obsidian/emaiax/70 - work";
      read = [ root ];
      write = [ root ];
    };
  };

  allVaults = builtins.attrValues vaults;
  allReads = builtins.concatMap (v: v.read) allVaults;
  allWrites = builtins.concatMap (v: v.write) allVaults;

  settings = {
    sandbox = {
      filesystem = {
        allowRead = allReads;
        allowWrite = allWrites;

        # `--settings` MERGES with the default layer and array values are
        # concatenated, so a profile can only widen the inherited scope — never
        # narrow it — except through denyWrite, which beats allowWrite even
        # across that merge. Without this, claude-sandbox.nix's `allowWrite`
        # would hand a vault session write access to every repo in ~/code.
        # Verified live against the merged config.
        denyWrite = [ "${home}/code" ];
      };

      network = {
        # "Local only" means nothing leaves via the shell. WebSearch, WebFetch
        # and MCP servers are in-process or separate processes and do NOT pass
        # through the sandbox, so deep research still works — that is intended,
        # not a gap. strictAllowlist removes the prompt fallback so an empty
        # allowlist really means empty.
        allowedDomains = [ ];
        strictAllowlist = true;

        # obsidian-cli speaks to Obsidian.app over this socket rather than over
        # HTTP or the obsidian:// scheme, so the profile needs it even with all
        # network denied.
        allowUnixSockets = [ "${home}/.obsidian-cli.sock" ];
      };
    };
  };

  settingsFile = (pkgs.formats.json { }).generate "claudio-settings.json" settings;

  # --add-dir grants the Read/Edit tools access to the vault; the sandbox block
  # above governs Bash. Both renders are needed because Read/Edit bypass the
  # sandbox entirely and go through the permission system instead.
  addDirArgs = lib.concatMapStringsSep " " (d: ''--add-dir "${d}"'') allReads;
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "claudio";
      runtimeInputs = [ config.programs.claude-code.package ];
      text = ''
        # cwd is writable by default, so it has to be a dedicated empty dir:
        # the vault would expose the whole vault, and $HOME the whole home.
        scratch="''${XDG_CACHE_HOME:-$HOME/.cache}/claudio/cwd"
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
