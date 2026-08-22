{ config, pkgs, ... }:
let
  configDirectory = "${config.home.homeDirectory}/code/dotfiles";
in
{
  home.packages = [ pkgs.any-nix-shell ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;

    defaultKeymap = "viins"; # emacs, vicmd, viins

    initContent = ''
      export PATH="${config.home.homeDirectory}/.bun/bin:$PATH"
      export PATH="${config.home.homeDirectory}/.asdf/shims:$PATH"

      any-nix-shell zsh --info-right | source /dev/stdin

      # decrypted async by a launchd agent, so this may not exist yet on a fresh login
      [[ -r "${config.sops.secrets.homelab-domain.path}" ]] &&
        export HOMELAB_DOMAIN="$(<"${config.sops.secrets.homelab-domain.path}")"
    '';

    shellAliases = {
      "~" = "cd ~";
      ".." = "cd ..";
      "../" = "cd ..";
      "..." = "cd ../..";

      # macOS helper to reload system settings applied from nix-darwin
      activateSettings = "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u";

      # dotfiles management
      #
      dotfiles = "cd ${configDirectory}";
      home-build = "just --justfile=${configDirectory}/justfile --working-directory=${configDirectory} build";
      home-switch = "just --justfile=${configDirectory}/justfile --working-directory=${configDirectory} switch";

      be = "bundle exec"; # bundle: rails apps
      cat = "bat -pp"; # bat: cat on steroids
      j = "just"; # just: task runner

      # claude: `claude-trust` and `claude-remote` dropped, both pinned a weaker posture than the default now provides. See claude-code/sandbox.nix.

      # claude-mem: semantic memory across sessions (see claude-mem.nix)
      claude-mem = "bun \"$(ls -dt ~/.claude/plugins/cache/thedotmack/claude-mem/*/scripts/worker-service.cjs 2>/dev/null | head -1)\"";

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
