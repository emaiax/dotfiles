{ ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    shellAliases = {
      cat = "bat";

      dotfiles = "cd ~/.config/nix";

      reload = "source ~/.zshrc";
    };
  };
}
