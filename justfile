# list options
default:
  @just --list

# build the configuration
build:
	darwin-rebuild build --flake .

# apply the configuration
apply:
	darwin-rebuild switch --flake .
