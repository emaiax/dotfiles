# this module is responsible for configuring homebrew and managing homebrew packages
# and should be imported by the darwin module and not by the home-manager module.
#
{ ... }:
{
  homebrew = {
    enable = true;

    # nix-homebrew is handling homebrew updates
    global.autoUpdate = true;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";

      extraFlags = [ "--force" ];
    };

    brews = [
      "openssl@1.1" # openssl@3: (libev) kqueue kevent: Bad file descriptor

      "coreutils"
      "gnupg"
      "gnutls"

      # rs-deps
      #
      "cmake"
      "jemalloc"
      "libxml2"
      "pkg-config"
      "readline"
      "ruby-build"
      "shared-mime-info"

      # databases and dev languages
      #
      "opensearch"
      "redis"

      {
        name = "mysql@8.0";
        link = true;
        start_service = true;
        restart_service = "changed";
      }

      {
        name = "postgresql@14";
        link = true;
        start_service = true;
        restart_service = "changed";
      }
    ];

    casks = [
      # applications
      #
      "1password-cli" # 1password cli
      "1password" # 1password
      "contexts" # context menu for mac
      "domzilla-caffeine" # caffeine
      "github" # github desktop for mac
      "logi-options+" # logitech options
      "obsidian" # note taking
      "rectangle" # window manager
      "slack" # communication
      "tableplus" # database management
      "the-unarchiver" # unarchiver

      # dependencies
      #
      "temurin" # java 17
    ];
  };
}
