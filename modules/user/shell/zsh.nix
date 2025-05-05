{ config, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    defaultKeymap = "viins"; # emacs, vicmd, viins

    initContent = ''
      export PATH="${config.home.homeDirectory}/.bun/bin:$PATH"
      export PATH="${config.home.homeDirectory}/.asdf/shims:$PATH"
    '';

    shellAliases = {
      activateSettings = "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u";

      cat = "bat";
      dotfiles = "cd ~/.config/nix";

      zr = "source ~/.zshrc"; # zsh reload
      zv = "cat ~/.zshrc"; # zsh view

      # rails apps
      be = "bundle exec";
    };
  };
}
