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
      # macOS helper to reload system settings applied from nix-darwin
      activateSettings = "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u";

      # goto dotfiles directory
      dotfiles = "cd ~/.config/nix";

      cat = "bat"; # cat with bat
      we = "watchexec";

      zv = "cat ~/.zshrc"; # view zshrc
      zr = "source ~/.zshrc"; # reload zshrc

      be = "bundle exec"; # rails apps
      iexmix = "iex -S mix"; # elixir terminal

      # mix tasks
      m = "mix";
      mt = "mix test";
      mtt = "mix test --trace";
      mtw = "mix test.watch";
      mtwt = "mix test.watch --trace";

      # phoenix tasks
      phxsrv = "mix phx.server";
      iexsrv = "iex -S mix phx.server";
    };
  };
}
