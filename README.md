# 🏠 Dotfiles

> Declarative system configuration using Nix with cross-platform support for macOS

A comprehensive, modular configuration management system built on [Nix][nix] that provides:
- **macOS System Management** via [Nix-Darwin][nix-darwin]
- **User Environment Configuration** via [Home Manager][home-manager] 
- **Package Management** via [Nix-Homebrew][nix-homebrew] integration
- **Multi-Host Support** with host-specific configurations
- **Multi-User Support** with user-specific profiles

## ✨ Features

- **🔧 Modular Architecture**: Organized into reusable modules for system, user, and host configurations
- **🖥️ Multi-Host Management**: Support for multiple machines with different architectures (Intel/Apple Silicon)
- **👥 Multi-User Support**: Separate profiles for personal and work environments
- **🍺 Homebrew Integration**: Declarative Homebrew package management through Nix
- **⚡ Development Tools**: Pre-configured CLI tools, shell environment, and development applications
- **🎨 macOS Customization**: System appearance, dock, finder, and security settings
- **🔄 Automated Updates**: Renovate for dependency management, Forgejo Actions for cheap checks, GitHub Actions for the aarch64-darwin build
- **📦 Flake-based**: Modern Nix flakes for reproducible and composable configurations

## 🏗️ Architecture

```
dotfiles/
├── 📁 nix/                      # Nix configuration inventory and overrides
│   ├── inventory.nix            # Host and user variable definitions
│   ├── 📁 hosts/                # Host-specific configurations
│   │   ├── dudumini.nix         # Intel Mac configuration
│   │   └── dudupro.nix          # Apple Silicon Mac configuration
│   │
│   └── 📁 profiles/             # User environment bundles and overrides
│       ├── emaiax.nix           # User configuration profile (emaiax)
│       └── brew.nix             # User-specific Homebrew packages
│
├── 📁 modules/                  # Modular configuration components
│   ├── 📁 core/                # Core Nix and system setup
│   │   ├── nix-daemon.nix      # Nix runtime and experimental features
│   │   ├── nixpkgs.nix         # Nixpkgs config and overlays
│   │   ├── system.nix          # System-level core config
│   │   ├── home-manager-setup.nix # Home Manager framework
│   │   └── default.nix         # Core module imports
│   │
│   ├── 📁 system/              # System-level configurations
│   │   ├── 📁 common/          # Cross-platform system configs
│   │   │   └── default.nix     # Environment variables and common settings
│   │   │
│   │   └── 📁 darwin/          # macOS system settings
│   │       ├── 📁 appearance/  # UI appearance and themes
│   │       ├── dock.nix        # Dock configuration
│   │       ├── finder.nix      # Finder settings
│   │       ├── keyboard.nix    # Keyboard preferences
│   │       ├── login-window.nix # Login window settings
│   │       ├── security/       # Security and authentication
│   │       ├── system.nix      # General system settings
│   │       ├── trackpad.nix    # Trackpad preferences
│   │       └── default.nix     # Darwin module imports
│   │
│   ├── 📁 user/                # User-level configurations
│   │   ├── 📁 apps/            # User applications
│   │   │   ├── 📁 iterm2/      # iTerm2 configuration
│   │   │   ├── 📁 raycast/     # Raycast launcher setup
│   │   │   └── 📁 vscode/      # VS Code configuration
│   │   ├── 📁 cli/             # Command-line tools (fzf, direnv, lsd)
│   │   ├── 📁 git/             # Git and GitHub CLI setup
│   │   ├── 📁 packages/        # Packages and package management
│   │   │   ├── fonts.nix       # Font configurations
│   │   │   └── default.nix     # User packages definition
│   │   ├── 📁 shell/           # Shell environment (Zsh, Starship, SSH)
│   │   └── default.nix         # User module imports
│   │
│   └── 📁 pkgs/                # Custom package definitions
│
├── 📁 scripts/                  # Installation and management scripts
│   ├── install.sh              # Automated installation script
│   └── uninstall.sh            # Clean removal script
│
├── 📁 .forgejo/workflows/        # Self-hosted CI (fmt, flake check, darwin eval)
├── 📁 .github/workflows/         # aarch64-darwin build (needs a real macOS runner)
│
├── renovate.json                # Dependency update automation (cross-repo, runs elsewhere)
├── flake.nix                   # Main Nix flake configuration
├── flake.lock                  # Locked dependency versions
├── justfile                    # Task runner commands
└── README.md                   # This file
```

## 🚀 Quick Start

### One-Line Installation

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/emaiax/dotfiles/HEAD/scripts/install.sh)"
```

### Manual Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/emaiax/dotfiles.git ~/.dotfiles
   cd ~/.dotfiles
   ```

2. **Run the installation script**:
   ```bash
   ./scripts/install.sh
   ```

The installation script will:
- Install Xcode Command Line Tools (if needed)
- Install Nix package manager
- Apply the configuration for your system

## 🔧 Usage

This project uses [just][just] as a task runner for common operations:

```bash
# List all available commands
just

# Apply configuration changes
just apply

# Build configuration without applying
just build

# Update all dependencies
just update

# Clean up old generations (>7 days)
just cleanup

# Show system information
just nix-info

# Generate SSH key
just ssh-keygen my-key "email@example.com"
```

### Adding a New Host

1. **Define the host in `nix/inventory.nix`**:
   ```nix
   hosts = {
     my-new-host = {
       hostname = "my-new-host";
       arch = "aarch64-darwin"; # or "x86_64-darwin"
       user = users.emaiax;     # or your user key
     };
   };
   ```

2. **Create host-specific configuration**:
   ```bash
   touch nix/hosts/my-new-host.nix
   ```

3. **Apply the configuration**:
   ```bash
   just apply
   ```

## 🛠️ Included Tools & Applications

### Command Line Tools
- **Shell**: Zsh with Starship prompt
- **File Management**: `lsd` (modern ls), `fzf` (fuzzy finder)
- **Development**: `direnv`, Git, GitHub CLI
- **System**: SSH configuration and key management

### macOS Applications
- **Terminal**: iTerm2 with custom configuration
- **Launcher**: Raycast for productivity
- **Editor**: VS Code with extensions
- **Package Management**: Homebrew integration

### System Customization
- **Appearance**: Dark mode, accent colors, UI preferences
- **Dock**: Auto-hide, positioning, and application management
- **Finder**: Show hidden files, path bar, and view preferences
- **Security**: Touch ID and Apple Watch authentication
- **Keyboard & Trackpad**: Custom key mappings and gesture settings

## 🔄 Continuous Integration

Development happens on a self-hosted Forgejo instance, which push-mirrors to GitHub:

- **Forgejo (`.forgejo/workflows/fast-ci.yml`)**: `nix fmt`, `nix flake check`, and an eval-only check of the aarch64-darwin closure — cheap, runs on every push/PR
- **GitHub (`.github/workflows/build.yml`)**: the actual aarch64-darwin build, on a real `macos-15` runner — Forgejo has no macOS runner and can't do this itself; its result is reported back to the Forgejo commit/PR via Forgejo's commit-status API
- **Dependency Updates**: Renovate, cross-repo automation that runs from a sibling repo, not a workflow in this one

## 🗑️ Uninstallation

To completely remove the configuration:

```bash
./scripts/uninstall.sh
```

This will:
- Remove Nix and all installed packages
- Clean up system modifications
- Restore original system settings

## 📚 Learning Resources

- [Nix Manual](https://nixos.org/manual/nix/stable/)
- [Nix-Darwin Manual](https://daiderd.com/nix-darwin/manual/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Flakes Tutorial](https://nixos.wiki/wiki/Flakes)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the configuration builds
5. Submit a pull request

## 📄 License

This project is open source. Feel free to use and modify as needed.

---

*Built with ❤️ using Nix*

[nix]: https://nixos.org/
[nix-darwin]: https://github.com/LnL7/nix-darwin
[nix-homebrew]: https://github.com/zhaofengli/nix-homebrew
[home-manager]: https://nix-community.github.io/home-manager/
[just]: https://github.com/casey/just
