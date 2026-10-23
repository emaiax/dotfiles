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

# flush the macOS DNS cache, including the negative answers mDNSResponder keeps
[macos]
flush-mdns-responder:
	#!/usr/bin/env bash
	set -euo pipefail
	# dscacheutil alone leaves mDNSResponder's own cache untouched, which is
	# where a stale NXDOMAIN for a name that now exists survives a flush.
	sudo dscacheutil -flushcache
	sudo killall -HUP mDNSResponder
	echo "flushed"

# load a project's flake devShell on cd, safe to rerun (just -f ~/code/dotfiles/justfile direnv-flake)
[no-cd]
direnv-flake dir=".":
	#!/usr/bin/env bash
	set -euo pipefail
	cd {{quote(dir)}}
	if [ ! -f flake.nix ]; then
		echo "no flake.nix in $PWD" >&2
		exit 1
	fi
	if [ ! -e .envrc ]; then
		echo "use flake" > .envrc
		echo "created .envrc"
	elif ! grep -qxE '[[:space:]]*use flake([[:space:]].*)?' .envrc; then
		# an existing .envrc is the project's, never rewrite it or trust it blindly
		echo ".envrc exists without 'use flake', left untouched. Add it yourself, then run 'direnv allow'" >&2
		exit 1
	fi
	direnv allow .
	echo "direnv allowed $PWD"

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

edit-secrets secret_file="secrets/secrets.enc.yaml":
	sops edit {{secret_file}}

set-secret secret_file key:
	#!/usr/bin/env bash
	set -euo pipefail
	read -rs -p "value: " value
	echo
	printf '%s' "$value" | jq -Rs . | sops set "{{secret_file}}" "[\"{{key}}\"]" --value-stdin

# remove one key
unset-secret secret_file key:
	sops unset {{secret_file}} "[\"{{key}}\"]"
