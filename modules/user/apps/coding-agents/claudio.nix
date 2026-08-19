# The `claudio` profile: Obsidian vault work through obsidian-cli (see #121).
#
# Layered on top of the default sandbox (claude-sandbox.nix) via `--settings`,
# which merges rather than replaces, so credential denies and gates are
# inherited rather than restated.
#
# The vault is reached ONLY through obsidian-cli. No vault path appears in the
# sandbox filesystem rules, so the agent cannot read or write vault files
# directly at all; every operation goes over the unix socket to Obsidian.app.
#
# What that buys and what it costs, stated plainly because the trade is not
# obvious:
#
#   - obsidian-cli operations carry Obsidian's own semantics — wikilink
#     resolution, the active file, the open app updating live — which direct
#     file writes do not.
#   - The sandbox cannot scope any of it. Obsidian.app performs the file
#     operations and is not sandboxed, so a filesystem rule would not apply
#     even if one were written. The socket also reaches every vault Obsidian
#     has open, not just this one; `vault=<name>` is a client-side argument,
#     not a server-side restriction.
#   - It requires Obsidian to be running. The socket is held open by the app
#     process, so with Obsidian closed the profile silently loses its only
#     path to the vault.
#
# Scoping the vault is therefore a matter of what the agent is told to do, not
# of what it is prevented from doing. If that ever needs to be a real boundary,
# it means dropping obsidian-cli and granting narrow filesystem paths instead —
# those two cannot both be true.
{
  config,
  pkgs,
  ...
}:
let
  home = config.home.homeDirectory;

  settings = {
    sandbox = {
      network = {
        # Deliberately not locked down otherwise: what needs containing is
        # published presence, which is a permission-gate concern, not a packet
        # one. Cutting egress only breaks fetching.
        #
        # obsidian-cli speaks to Obsidian.app over this socket rather than over
        # HTTP or the obsidian:// scheme. Unix sockets are governed separately
        # from domains, so this entry is required regardless of the above.
        allowUnixSockets = [ "${home}/.obsidian-cli.sock" ];
      };

      filesystem = {
        # `allowUnixSockets` authorises connecting to the socket, not stat'ing
        # its path, and the default layer denies all of $HOME. obsidian-cli
        # connects without checking first so it works either way, but anything
        # that probes for the socket before using it would fail confusingly.
        allowRead = [ "${home}/.obsidian-cli.sock" ];

        # `--settings` merges and concatenates arrays, so a profile can only
        # widen the inherited scope — never narrow it — except through
        # denyWrite, which beats allowWrite even across that merge. Without
        # this, a vault session would inherit claude-sandbox.nix's allowWrite
        # and could write every repo in ~/code. Verified live.
        denyWrite = [ "${home}/code" ];
      };
    };
  };

  settingsFile = (pkgs.formats.json { }).generate "claudio-settings.json" settings;
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "claudio";
      runtimeInputs = [ config.programs.claude-code.package ];
      text = ''
        # cwd is writable by default and only an explicit denyWrite overrides
        # that. The rule above already covers ~/code, so launching from a repo
        # there is safe — but nowhere else in $HOME is covered, and launching
        # from, say, ~/Documents would quietly make that directory writable.
        # Verified: a write in cwd succeeds under an uncovered path and is
        # denied under ~/code.
        #
        # Forcing an empty scratch directory means the only writable place is
        # one that holds nothing, whatever directory the command was typed in.
        scratch="''${XDG_CACHE_HOME:-$HOME/.cache}/claudio/cwd"
        mkdir -p "$scratch"
        cd "$scratch"

        exec claude --settings ${settingsFile} "$@"
      '';
    })
  ];
}
