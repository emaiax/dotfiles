{ ... }:
{
  programs.ssh = {
    enable = true;

    addKeysToAgent = "yes";
    forwardAgent = true;

    serverAliveInterval = 60;

    extraOptionOverrides = {
      IgnoreUnknown = "UseKeychain";
      UseKeyChain = "yes";
    };

    matchBlocks = {
      "homelab" = {
        host = "*.homelab.local";
        user = "root";

        identityFile = "~/.ssh/homelab";
        identitiesOnly = true;

        extraOptions = {
          UserKnownHostsFile = "/dev/null";
          StrictHostKeyChecking = "false";
        };
      };
    };
  };
}
