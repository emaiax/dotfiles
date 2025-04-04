{ config, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    defaultKeymap = "viins"; # emacs, vicmd, viins

    initExtra = ''
      export PATH="$PATH:${config.home.homeDirectory}/.bun/bin"
      export PATH="$PATH:${config.home.homeDirectory}/.asdf/shims"
    '';

    shellAliases = {
      cat = "bat";

      dotfiles = "cd ~/.config/nix";

      reload = "source ~/.zshrc";
    };
  };
}
