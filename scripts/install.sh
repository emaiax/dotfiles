#!/bin/bash

# Exit on error
set -e

# Install Xcode developer tools
if ! comand -v xcode-select >/dev/null 2>&1; then
    echo "Installing Xcode developer tools..."
    xcode-select --install
    echo "Xcode developer tools installation complete. Please restart your terminal and re-run this script to continue."
    exit 0
else
    echo "Xcode developer tools are already installed. Skipping installation."
fi

# Install Nix if not already installed
if ! command -v nix >/dev/null 2>&1; then
    echo "Installing Nix..."
    curl -L https://nixos.org/nix/install | sh
    echo "Nix installation complete. Please restart your terminal and re-run this script to continue."
    exit 0
else
    echo "Nix is already installed. Skipping installation."
fi

# Create the configuration folder if it doesn't exist
echo "Ensuring Nix configuration directory exists..."
mkdir -p "$HOME/.config/nix"

# Navigate to the configuration directory
if cd "$HOME/.config/nix"; then
    # Install dotfiles using nix-darwin
    if [ -f "flake.nix" ]; then
        echo "Installing dotfiles with nix-darwin..."
        nix --extra-experimental-features "nix-command flakes" run "nix-darwin/master#darwin-rebuild" -- switch --flake .
    else
        echo "flake.nix not found in $HOME/.config/nix. Skipping dotfiles installation."
    fi
else
    echo "Failed to change directory to $HOME/.config/nix."
    exit 1
fi

echo "Installation complete."
