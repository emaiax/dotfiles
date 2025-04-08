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
      activateSettings = "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u";

      cat = "bat";
      dotfiles = "cd ~/.config/nix";

      zr = "source ~/.zshrc"; # zsh reload
      zv = "cat ~/.zshrc"; # zsh view
    };
  };
}
