{ config, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    defaultKeymap = "viins"; # emacs, vicmd, viins

    initExtra = ''
      export PATH="$PATH:${config.home.homeDirectory}/.asdf/shims" # Add asdf binaries to PATH
    '';

    shellAliases = {
      cat = "bat";

      dotfiles = "cd ~/.config/nix";

      reload = "source ~/.zshrc";
    };
  };
}
