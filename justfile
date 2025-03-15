# list options
default:
  @just --list

# build the configuration
build:
	@darwin-rebuild build --flake .

# apply the configuration
apply:
	@darwin-rebuild switch --flake .

# generate SSH key for a given name and comment
ssh-keygen NAME COMMENT:
	@ssh-keygen -t ed25519 -f ~/.ssh/{{NAME}} -C "{{COMMENT}}"

