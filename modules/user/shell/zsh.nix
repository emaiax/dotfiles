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
      "~" = "cd ~";
      ".." = "cd ..";

      # macOS helper to reload system settings applied from nix-darwin
      activateSettings = "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u";

      be = "bundle exec"; # bundle: rails apps
      cat = "bat -pp"; # bat: cat on steroids
      dotfiles = "cd ~/.config/nix"; # goto dotfiles directory

      # just: https://just.systems/man/en/global-and-user-justfiles.html
      j = "just";
      jg = "just --global-justfile";

      # mix: elixir tests
      mt = "mix test";
      mtt = "mix test --trace";
      mtw = "mix test.watch";
      mtwt = "mix test.watch --trace";

      # mix: elixir tasks
      miex = "iex -S mix";
      miphx = "iex -S mix phx.server";
      mphx = "mix phx.server";

      # watchexec: watch for file changes and run commands
      we = "watchexec --clear --timings";

      # zsh: view and reload configuration files
      zv = "cat ~/.zshrc"; # view zshrc
      zr = "source ~/.zshrc"; # reload zshrc
    };
  };
}
