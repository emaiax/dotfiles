{ ... }:
{
  programs.ssh = {
    enable = true;

    identityFile = "~/.ssh/id_ed25519";
    addKeysToAgent = "yes";
    forwardAgent = true;

    serverAliveInterval = 60;

    extraOptionOverrides = {
      IgnoreUnknown = "UseKeychain";
      UseKeyChain = "yes";

      setEnv = {
        TERM = "xterm-256color";
      };

      sendEnv = [
        "COLORTERM"
      ];
    };


    matchBlocks = {
      "homelab" = {
        identityFile = "~/.ssh/homelab";
        host = "*.homelab.local";
        user = "root";

        extraOptions = {
          UserKnownHostsFile = "/dev/null";
          StrictHostKeyChecking = "false";
        };
      };
    };
  };
}
