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
      "../" = "cd ..";
      "..." = "cd ../..";

      # macOS helper to reload system settings applied from nix-darwin
      activateSettings = "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u";

      # dotfiles: https://github.com/emaiax/dotfiles
      #
      home-config = "cd ${configDirectory}";
      home-build = "just --justfile=${configDirectory}/justfile --working-directory=${configDirectory} build-custom";
      home-switch = "just --justfile=${configDirectory}/justfile --working-directory=${configDirectory} apply-custom";

      be = "bundle exec"; # bundle: rails apps
      cat = "bat -pp"; # bat: cat on steroids
      j = "just"; # just: task runner

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
      we = "watchexec --clear=clear --timings";

      # zsh: view and reload configuration files
      zv = "cat ~/.zshrc"; # view zshrc
      zr = "source ~/.zshrc"; # reload zshrc
    };
  };
}
