# Dotfiles

This repository contains configuration files managed using [Nix][nix], [Nix-Darwin][nix-darwin], [Nix-Homebrew][nix-homebrew], and [Home Manager][home-manager].

This setup leverages the power of Nix, Nix-Darwin, and Home Manager to manage system and user-specific configurations declaratively. It ensures reproducibility and ease of configuration management.

- [Nix][nix] is a powerful package manager that makes package management reliable and reproducible. It uses a purely functional approach, ensuring that builds are isolated and deterministic.

- [Nix-Darwin][nix-darwin] is a macOS-specific framework built on top of Nix. It provides functionality similar to Homebrew but with the added benefit of declarative system configuration.

- [Nix-Homebrew][nix-homebrew]: A bridge between Nix and Homebrew, allowing you to use Homebrew packages within the Nix ecosystem. It provides flexibility for users who rely on Homebrew while leveraging Nix's declarative configuration.

- [Home Manager][home-manager] is a tool for managing user-specific configurations using Nix. It integrates seamlessly with Nix-Darwin to manage dotfiles and other user-level settings.

## Structure

The repository is organized as follows:

- `hosts/`: host-specific configurations, each file represents a specific machine or environment
- `modules/`: reusable Nix modules to organize configurations (e.g., apps, services, and custom settings)
- `profiles/`: profiles for different users or environments (e.g., personal, work, vms)
- `scripts/`: helper scripts for installation and uninstallation

## Installation

Run the provided installation script to set up everything automatically:

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
