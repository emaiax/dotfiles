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

      # kvm is intentionally not listed: the VM boots via QEMU+HVF
      # (accel=hvf:tcg) and does not expose /dev/kvm to the guest, so
      # nested-virtualization builds (nixosTest with a VM backend) cannot
      # actually run here. Declaring kvm anyway lets Nix schedule such
      # builds onto this machine, where they fail with a garbled exec
      # error instead of a clean "missing system features" rejection.
      # See dotfiles#82.
      #
      # nixos-test and uid-range are listed so container-backed nixosTest
      # derivations (systemd-nspawn, e.g. most prometheus exporter tests)
      # can schedule here. uid-range requires auto-allocate-uids below —
      # without it the build sandbox keeps the real single build uid
      # (no root inside the container), and systemd-nspawn refuses to run.
      supportedFeatures = [
        "benchmark"
        "big-parallel"
        "nixos-test"
        "uid-range"
      ];

      config = {
        nix.settings = {
          # cgroups is required alongside auto-allocate-uids/uid-range for
          # container-backed nixosTest derivations (systemd-nspawn) to
          # actually spawn on this builder.
          extra-experimental-features = [
            "auto-allocate-uids"
            "cgroups"
          ];
          auto-allocate-uids = true;

          # NixOS's own `nix.settings.system-features` default
          # (nixos/modules/config/nix.nix) is a static list that predates
          # auto-allocate-uids and does not add "uid-range" for it, unlike
          # plain Nix's dynamic default. `extra-system-features` appends to
          # that static list instead of replacing it.
          extra-system-features = [ "uid-range" ];
        };

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

    gc = {
      automatic = true;
      # no Weekday set — StartCalendarInterval treats an omitted field as
      # "every", so this fires daily instead of nix-darwin's weekly default.
      # 10am (not the middle of the night) so it's more likely to catch the
      # Mac already awake instead of relying on the sleep/wake catch-up.
      interval = {
        Hour = 10;
        Minute = 0;
      };
      options = "--delete-older-than 7d";
    };

    optimise = {
      automatic = true;
      interval = {
        Hour = 10;
        Minute = 15;
      };
    };
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
