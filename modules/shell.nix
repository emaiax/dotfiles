{ ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    shellAliases = {
      ls = "ls --color=auto";
      ll = "ls -lah --color=auto";
      dotfiles = "cd ~/.config/nix";
    };
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };
}
