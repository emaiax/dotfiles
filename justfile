# list available options
default:
	@just --list

# activate macOS settings
[macos]
activate-settings:
	#!/usr/bin/env bash
	echo "Activating macOS settings..."
	/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

# apply the configuration
apply *FLAGS:
	@git add .
	@darwin-rebuild switch --flake . {{FLAGS}}
	@just activate-settings

# build the configuration
build *FLAGS:
	@git add .
	@darwin-rebuild build --flake . {{FLAGS}}

# cleanup old home-manager and nix generations (> 7 days)
cleanup:
	@nix-collect-garbage --delete-old --delete-older-than 7d

# show the dependency tree and graph
dependency-graph:
	@nix-store -q --tree /nix/var/nix/profiles/system

# list user activations
list-user-activations:
	@ls -la /nix/var/nix/profiles/system/activate-user

# update flake lock file
update:
	@nix flake update

# generate SSH key for a given name and comment
ssh-keygen NAME COMMENT:
	@ssh-keygen -t ed25519 -f ~/.ssh/{{NAME}} -C "{{COMMENT}}"
