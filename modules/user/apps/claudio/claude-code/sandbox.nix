# Default sandbox layer for every Claude Code session (see #121). Confines Bash and its children only.
# Read/Edit/Write go through claude-code.nix's permissions.deny instead (see #126), both built from
# claudio/permissions.nix. Profiles layer on top via `--settings`, which merges, so they inherit every deny here.
# Background/investigation notes: ../docs/sandbox-notes.md.
#
# Two ways to write a rule that silently does nothing: a trailing slash voids the entry on 2.1.222 (fixed in
# 2.1.224), and a glob like `$HOME/*` matches nothing and fails open.
{
  config,
  lib,
  dotfilesPath,
  ...
}:
let
  home = config.home.homeDirectory;

  # Shared with claude-code.nix and opencode/default.nix. filesystem/network policy lives entirely in
  # permissions.nix, this file only wires it plus the Seatbelt toggles that aren't data.
  perms = import ../permissions.nix { inherit home lib dotfilesPath; };
in
{
  programs.claude-code.settings.sandbox = {
    enabled = true;

    # Without both, the boundary is advisory: Claude may retry a blocked command unsandboxed, or continue if
    # Seatbelt is unavailable.
    allowUnsandboxedCommands = false;
    failIfUnavailable = true;

    autoAllowBashIfSandboxed = true;

    # docker/gh/fj policy: permissions.nix's claudeCode.sandbox.excludedCommands.
    inherit (perms.claudeCode.sandbox) excludedCommands;

    # Without this, `open -a <App>` fails with kLSUnknownErr: launching another app's process needs a mach-lookup
    # to RunningBoard/launchservicesd that the sandbox blocks.
    allowAppleEvents = true;

    network = perms.claudeCode.sandbox.network;
    filesystem = perms.claudeCode.sandbox.filesystem;
  };
}
