{ ... }:
{
  programs.ssh = {
    enable = true;

    enableDefaultConfig = false;

    extraOptionOverrides = {
      IgnoreUnknown = "UseKeychain";
      UseKeyChain = "yes";
    };

    settings = {
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

        userKnownHostsFile = "/dev/null";
        strictHostKeyChecking = "no";
      };
    };
  };
}
