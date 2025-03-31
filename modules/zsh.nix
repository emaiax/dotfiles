{ ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    defaultKeymap = "viins"; # emacs, vicmd, viins

    shellAliases = {
      cat = "bat";

      dotfiles = "cd ~/.config/nix";

      reload = "source ~/.zshrc";
    };
  };
}
