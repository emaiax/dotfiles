let
  agents = [
    "claude"
    "opencode"
  ];
in
{
  programs.agent-jail.profiles = {
    emx = { inherit agents; };
    work = { inherit agents; };
  };
}
