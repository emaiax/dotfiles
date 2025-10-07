{ ... }:
{
  programs.ssh = {
    enable = true;

    enableDefaultConfig = false;

    extraOptionOverrides = {
      IgnoreUnknown = "UseKeychain";
      UseKeyChain = "yes";
    };

    matchBlocks = {
      "*" = {
        addKeysToAgent = "yes";
        forwardAgent = true;
        serverAliveInterval = 60;
      };

      "github.com" = {
        identitiesOnly = true;
        identityFile = "~/.ssh/github";
      };

      "homelab" = {
        host = "*.local";
        user = "root";

        identitiesOnly = true;
        identityFile = "~/.ssh/homelab_id_ed25519";

        extraOptions = {
          UserKnownHostsFile = "/dev/null";
          StrictHostKeyChecking = "false";
        };
      };
    };
  };
}
