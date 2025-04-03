# Dotfiles

Declarative configuration using [Nix][nix] with [Nix-Darwin][nix-darwin] for macOS system management, [Home Manager][home-manager] for user environments and [Nix-Homebrew][nix-homebrew] integration for macOS package management.

## Structure

```
dotfiles/
├── hosts/
│   ├── common/        # shared machine configs
│   ├── darwin/        # macOS host tuning
│   ├── linux/         # linux host tuning
│   └── machine.nix    # hardware-specific overrides
│
├── modules/
│   ├── core/          # core setup (nix, homebrew, home-manager)
│   │
│   ├── system/        # system configs and services managed by nix-darwin
│   │   ├── common/    # cross-platform system-level configs
│   │   ├── darwin/    # macOS system-level settings and applications
│   │   └── linux/     # linux system-level settings and applications
│   │
│   └── user/          # user configs and applications managed by home-manager
│       ├── cli/       # command line tools and utilities
│       ├── common/    # cross-platform user configs
│       ├── darwin/    # macOS user-level settings and applications
│       │   └── apps/  # macOS GUI apps (iterm2, raycast, vscode)
│       ├── linux/     # linux user-level settings and applications
│       └── shell/     # shell runtime
│
└── profiles/          # user environment bundles
    ├── emaiax.nix     # personal config and imports
    └── work.nix       # work-specific setup
```

## Installation

Paste the install command in a shell prompt to install.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/emaiax/dotfiles/HEAD/scripts/install.sh)"
```

Or you can manually run the provided installation script to set up everything:

```bash
./scripts/install.sh
```

## Uninstallation

Run the provided uninstallation script to clean up everything:

```bash
./scripts/uninstall.sh
```

[nix]: https://nixos.org/
[nix-darwin]: https://github.com/LnL7/nix-darwin
[nix-homebrew]: https://github.com/NixOS/homebrew-nix
[home-manager]: https://nix-community.github.io/home-manager/
