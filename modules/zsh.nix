{ ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    shellAliases = {
      cat = "bat";
      dotfiles = "cd ~/.config/nix";
      ll = "ls -lah --color=auto";
      ls = "ls --color=auto";

      reload = "source ~/.zshrc";
    };
  };
}
