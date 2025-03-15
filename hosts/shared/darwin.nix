{ pkgs, ... }:
{
  imports = [
    ../../modules/brew.nix
  ];

  nix.settings.trusted-users = [
    "root"
    "emaiax"
  ];

  environment.systemPackages = with pkgs; [ raycast ];

  nixpkgs.config = {
    allowUnfree = true;
  };

  users.users.emaiax = {
    name = "emaiax";
    home = "/Users/emaiax";
  };


  system = {
    # still depending on https://github.com/LnL7/nix-darwin/pull/699 to be merged
    # keyboard.shortcuts = {
    #   enable = true;
    #
    #   spotlight.search.enable = false;
    #   spotlight.search.finderSearch = false;
    # };

    defaults = {
      dock = {
        autohide = true;
      };

      finder = {
        _FXShowPosixPathInTitle = true;
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "Nlsv";
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        ShowPathbar = false;
        ShowStatusBar = true;
      };

      NSGlobalDomain.AppleShowAllExtensions = true;
      # NSGlobalDomain.InitialKeyRepeat = 14;
      # NSGlobalDomain.KeyRepeat = 14;
    };
  };
}
