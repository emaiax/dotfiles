# Antigravity CLI adapter: permission approvals and policy translation.
{
  lib,
  policy,
}:
let
  allowRule =
    cmd:
    if lib.hasPrefix "command(" cmd then
      cmd
    else if lib.hasSuffix "*" cmd then
      "command(${cmd})"
    else if cmd == "ssh -o ProxyCommand=" then
      "command(${cmd})"
    else
      "command(${cmd} *)";
in
{
  permissions = {
    allow = map allowRule policy.commands.allow;
  };
}
