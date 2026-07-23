{ ... }:
{
  sops.secrets."agent-jail-profiles" = {
    sopsFile = ../../../../secrets/agent-jail-profiles.enc.json;
    format = "json";
    key = "";
  };
}
