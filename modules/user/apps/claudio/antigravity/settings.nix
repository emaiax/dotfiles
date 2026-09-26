# Antigravity CLI adapter: permission approvals and policy translation.
# https://antigravity.google/docs/cli/reference/#configuration-keys-settingsjson
{
  lib,
  policy,
}:
let
  exactRule = cmd: if lib.hasPrefix "command(" cmd then cmd else "command(${cmd})";

  allowRule =
    cmd:
    if lib.hasPrefix "command(" cmd then
      cmd
    else if lib.hasSuffix "*" cmd then
      "command(${cmd})"
    else if cmd == "ssh -o ProxyCommand=" then # ensure the ProxyCommand is wrapped correctly
      "command(${cmd})"
    else
      "command(${cmd} *)";
in
{
  permissions = {
    allow = map allowRule policy.commands.allow;
    ask = map allowRule policy.commands.ask ++ map exactRule (policy.commands.askExact or [ ]);
    deny = map allowRule policy.commands.deny;
  };
}
