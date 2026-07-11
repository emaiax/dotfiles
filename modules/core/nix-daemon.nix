{
  host,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  nix = {
    package = lib.mkDefault pkgs.nix;

    linux-builder = {
      enable = true;
      ephemeral = true;

      maxJobs = 4;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      supportedFeatures = [
        "kvm"
        "benchmark"
        "big-parallel"
      ];

      config = {
        virtualisation = {
          cores = 4;

          darwin-builder = {
            # diskSize = 10 * 1024; # defaults to 20G
            memorySize = 8 * 1024;
          };
        };
      };
    };

    settings = {
      experimental-features = "nix-command flakes";
      flake-registry = ./registry.json;
      accept-flake-config = true;

      trusted-users = [
        "root"
        host.user.username
      ];
    };

    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';
  };

  # nix-darwin's linux-builder VM has a deterministic SSH host key (stored in
  # /var/lib/linux-builder/keys, persisted across `ephemeral = true` disk wipes),
  # matching the `publicHostKey` nix-darwin embeds in /etc/nix/machines. It is
  # never added to any known_hosts file automatically, so both root (nix-daemon,
  # for real distributed builds) and interactive users get "Host key verification
  # failed" until it's trusted once. Provisioning it declaratively here covers
  # both, instead of a manual `ssh-keyscan`/known_hosts edit.
  environment.etc."ssh/ssh_known_hosts".text = ''
    linux-builder ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBWcxb/Blaqt1auOtE+F8QUWrUotiC5qBJ+UuEWdVCb
  '';
}
