# dotfiles

sh <(curl -L https://nixos.org/nix/install)

mkdir -p ~/.config/nix
cd ~/.config/nix

# generate initial flake
nix --extra-experimental-features "nix-command flakes" flake init -t nix-darwin/master 

# first install nix-darwin
nix --extra-experimental-features "nix-command flakes" run "nix-darwin/master#darwin-rebuild" -- switch --flake .

# to rebuild later
darwin-rebuild switch --flake .