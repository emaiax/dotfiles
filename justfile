# justfile: https://just.systems/man/en/global-and-user-justfiles.html
set unstable := true

default:
	@just --list --unsorted

# update flake lock file
update:
	@nix flake update

# watch for file changes and run commands
auto target *flags:
    watchexec --clear --timings just {{target}} {{flags}}

# activate macOS settings
[macos]
activate-settings:
	#!/usr/bin/env bash
	echo "Activating macOS settings..."
	/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

# nix-darwin switch the configuration
switch *FLAGS:
	git add .
	sudo darwin-rebuild switch --flake . {{FLAGS}}
	just activate-settings

# nix-darwin build the configuration
build *FLAGS:
	git add .
	darwin-rebuild build --flake . {{FLAGS}}

# cleanup old home-manager and nix generations (> 7 days)
[confirm: "Are you sure you want to cleanup old home-manager and nix generations? (y/n)"]
nix-cleanup:
	# delete old nix store
	nix-store --gc

	# delete old home-manager generations
	nix-collect-garbage --delete-old --delete-older-than 7d

	# delete old nix generations
	sudo nix-collect-garbage --delete-old --delete-older-than 7d

	# reshim asdf if exists
	if command -v asdf > /dev/null; then asdf reshim; fi

# start a nix repl with the nixpkgs flake
repl:
	@nix repl -f '<nixpkgs>'

# print nix info
nix-info:
	@nix-shell -p nix-info --run "nix-info -m"
# show the dependency tree and graph

dependency-graph:
	@nix-store -q --tree /nix/var/nix/profiles/system

# list user activations
list-user-activations:
	@ls -la /nix/var/nix/profiles/system/activate-user

# generate SSH key for a given name and comment
ssh-keygen NAME COMMENT:
	@ssh-keygen -t ed25519 -f ~/.ssh/{{NAME}} -C "{{COMMENT}}"

copy-ssh-key-to-host key host:
  ssh-copy-id -i {{key}} {{host}}

# decrypt a sops file in place for editing (SOPS_AGE_KEY_FILE comes from modules/user/sops/default.nix, not this justfile)
decrypt secret_file:
	sops --decrypt --in-place {{secret_file}}

# re-encrypt a sops file after decrypt
encrypt secret_file:
	sops --encrypt --in-place {{secret_file}}
