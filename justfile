# justfile: https://just.systems/man/en/global-and-user-justfiles.html
set unstable := true

default:
	@just --list --unsorted

# watch for file changes and run commands
auto target *flags:
    watchexec --clear --timings just {{target}} {{flags}}

# activate macOS settings
[macos]
activate-settings:
	#!/usr/bin/env bash
	echo "Activating macOS settings..."
	/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

# apply the configuration
apply *FLAGS:
	git add .
	sudo darwin-rebuild switch --flake . {{FLAGS}}
	just activate-settings

# build the configuration
build *FLAGS:
	git add .
	darwin-rebuild build --flake . {{FLAGS}}

custom-home-manager := "--override-input home-manager ~/code/home-manager"

build-custom *FLAGS:
	just build "{{ custom-home-manager }} {{FLAGS}}"

apply-custom *FLAGS:
	just apply "{{ custom-home-manager }} {{FLAGS}}"

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

# update flake lock file
update:
	@nix flake update

# generate SSH key for a given name and comment
ssh-keygen NAME COMMENT:
	@ssh-keygen -t ed25519 -f ~/.ssh/{{NAME}} -C "{{COMMENT}}"
