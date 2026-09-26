# OpenCode adapter: maps canonical policy to the permission object in opencode.json.
{
  lib,
  policy,
}:
let
  denyCommands = policy.commands.deny or [ ];
in
{
  permission = {
    read = {
      "*" = "allow";
      "*.env" = "deny";
      "*.env.*" = "deny";
      "*.env.example" = "allow";
    };
    glob = "allow";
    grep = "allow";
    lsp = "allow";
    edit = "allow";
    webfetch = "allow";
    websearch = "allow";
    task = "allow";
    external_directory = "ask";
    doom_loop = "deny";
    bash = {
      "*" = "allow";
    }
    // (lib.genAttrs policy.commands.allow (_: "allow"))
    // (lib.genAttrs (policy.commands.ask or [ ]) (_: "ask"))
    // (lib.genAttrs denyCommands (_: "deny"));
  };
}
