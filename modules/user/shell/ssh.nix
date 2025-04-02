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
      "github.com" = {
        identitiesOnly = true;
        identityFile = "~/.ssh/github";
      };

      "homelab" = {
        host = "*.homelab.local";
        user = "root";

        identitiesOnly = true;
        identityFile = "~/.ssh/homelab";

        extraOptions = {
          UserKnownHostsFile = "/dev/null";
          StrictHostKeyChecking = "false";
        };
      };
    };
  };
}
