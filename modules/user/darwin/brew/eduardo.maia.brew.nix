# this module is responsible for configuring homebrew and managing homebrew packages
# and should be imported by the darwin module and not by the home-manager module.
# 
{ ... }:
{
  homebrew = {
    enable = true;

    # nix-homebrew is handling homebrew updates
    global.autoUpdate = true;

    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
    onActivation.cleanup = "zap";

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
      "mysql@8.0"
      "opensearch"
      "postgresql@14"
      "redis"
    ];

    casks = [
      # applications
      #
      "1password-cli"     # 1password cli
      "1password"         # 1password
      "contexts"          # context menu for mac
      "domzilla-caffeine" # caffeine
      "github"            # github desktop for mac
      "logi-options+"     # logitech options
      "obsidian"          # note taking
      "rectangle"         # window manager
      "slack"             # communication
      "tableplus"         # database management
      "the-unarchiver"    # unarchiver

      # dependencies
      #
      "temurin"           # java 17
    ];
  };
}
