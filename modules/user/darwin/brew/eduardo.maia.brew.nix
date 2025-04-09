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

    taps = [
      "hashicorp/tap"
    ];

    brews = [
      "cmake"
      "coreutils"
      "gnupg"
      "gnutls"
      "hashicorp/tap/vault"
      "jemalloc"
      "libxml2"
      "openssl@1.1" # openssl@3: (libev) kqueue kevent: Bad file descriptor
      "pkg-config"
      "readline"
      "ruby-build"
      "shared-mime-info"

      {
        name = "mysql@8.0";
        link = true;
        start_service = false;
      }

      {
        name = "postgresql@14";
        link = true;
        start_service = false;
      }
    ];

    casks = [
      # applications
      #
      "1password-cli" # 1password cli
      "1password" # 1password
      "contexts" # context menu for mac
      "domzilla-caffeine" # caffeine
      "docker" # docker desktop for mac
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
