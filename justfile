# list options
default:
  @just --list

# apply the configuration
apply *FLAGS:
	@git a
	@darwin-rebuild switch --flake . {{FLAGS}}

# build the configuration
build *FLAGS:
	@git a
	@darwin-rebuild build --flake . {{FLAGS}}

# cleanup home-manager and nix generations
cleanup:
	@./result/sw/bin/nix-collect-garbage --delete-old --delete-older-than 2d

# generate SSH key for a given name and comment
ssh-keygen NAME COMMENT:
	@ssh-keygen -t ed25519 -f ~/.ssh/{{NAME}} -C "{{COMMENT}}"
