# Claude Code adapter: Seatbelt sandbox, file/directory rules, and profile permissions.
{ lib, policy }:
let
  cleanCmd = cmd: lib.removeSuffix " " (lib.removeSuffix "*" (lib.removeSuffix " *" cmd));
  prefixRule = cmd: "Bash(${cleanCmd cmd}:*)";
  exactRule = cmd: "Bash(${cmd})";

  withRtkTwin =
    cmds:
    lib.concatMap (cmd: [
      cmd
      "rtk ${cmd}"
    ]) cmds;

  absPath = path: lib.removePrefix "/" path;

  # Auto-defense: file rules + .bak backup twin rules
  fileRules = path: [
    "Read(//${absPath path})"
    "Edit(//${absPath path})"
    "Read(//${absPath path}.bak)"
    "Edit(//${absPath path}.bak)"
  ];

  # Auto-defense: directory rules (recursive /**)
  dirRules = path: [
    "Read(//${absPath path}/**)"
    "Edit(//${absPath path}/**)"
  ];

  # Auto-defense: extra/unknown path (covers file, .bak, and recursive dir)
  extraPathRules = path: (fileRules path) ++ (dirRules path);

  credentialDenyRules =
    lib.concatMap fileRules policy.filesystem.credentials.files
    ++ lib.concatMap dirRules policy.filesystem.credentials.dirs
    ++ lib.concatMap extraPathRules (policy.filesystem.credentials.extra or [ ]);

  askRules =
    map prefixRule (withRtkTwin policy.commands.ask)
    ++ map exactRule (withRtkTwin policy.commands.askExact);

  denyCommands = policy.commands.deny or [ ];

  mkPermissions =
    {
      deny ? false,
      hardDeny ? deny,
    }:
    let
      denyRules = lib.optionals hardDeny (map prefixRule (withRtkTwin denyCommands));
    in
    {
      allow = map prefixRule (withRtkTwin policy.commands.allow);
      ask = askRules;
      deny = denyRules ++ credentialDenyRules;
    };

  mkSandbox = {
    excludedCommands = policy.commands.bypassSandboxSeatbelt;
    network = policy.network;
    filesystem = {
      disabled = true; # allowWrite is a no-op upstream; network sandbox stays active
      allowRead =
        policy.network.allowUnixSockets
        ++ policy.filesystem.toolchainReadOnly
        ++ policy.filesystem.toolchainReadWrite;
      allowWrite = policy.filesystem.toolchainReadWrite;
      denyRead = [
        policy.filesystem.home
      ]
      ++ policy.filesystem.credentials.dirs
      ++ policy.filesystem.credentials.files
      ++ (policy.filesystem.credentials.extra or [ ]);
      denyWrite = [
        policy.filesystem.home
      ]
      ++ policy.filesystem.credentials.dirs
      ++ policy.filesystem.credentials.files
      ++ (policy.filesystem.credentials.extra or [ ]);
    };
  };

in
{
  inherit
    credentialDenyRules
    mkPermissions
    mkSandbox
    ;

  sandbox = mkSandbox;
  permissions = mkPermissions { hardDeny = true; };
}
