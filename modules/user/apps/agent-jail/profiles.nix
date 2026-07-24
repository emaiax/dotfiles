let
  agents = (builtins.attrNames (import ./agents.nix));
in
{
  programs.agent-jail.profiles = {
    emx = { inherit agents; };
    work = {
      inherit agents;
      cwd = {
        rw = false;
      };
    };
  };
}
