{
  host,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  nix = {
    package = lib.mkDefault pkgs.nix;

    settings = {
      experimental-features = "nix-command flakes";

      trusted-users = [
        "root"
        host.user.username
      ];
    };

    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';
  };

  nixpkgs = {
    config.allowUnfree = true;
    config.allowUnsupportedSystem = true;

    hostPlatform = host.arch;

    overlays = [ inputs.nix-vscode-extensions.overlays.default ];
  };

  system = {
    primaryUser = host.user.username;

    # Set Git commit hash for darwin-version.
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

    # Used for backwards compatibility, please read the changelog before changing.
    stateVersion = 6;
  };
}
