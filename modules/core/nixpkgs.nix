{
  host,
  inputs,
  pkgs,
  ...
}:
{
  nixpkgs = {
    config = {
      allowBroken = false;
      allowUnfree = true;
      allowUnsupportedSystem = true;

      # some unmaintained packages are allowed to be installed
      #
      permittedInsecurePackages = map (pkg: pkg.name) [ pkgs.arc-browser ];
    };

    hostPlatform = host.arch;

    overlays = [
      inputs.nix-vscode-extensions.overlays.default
      # direnv + CGO_ENABLED=0 + Darwin Makefile -linkmode=external (nixpkgs#502769).
      # Remove after nixpkgs includes that postPatch (nix flake update).
      (_final: prev: {
        direnv = prev.direnv.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            if grep -q -- ' -linkmode=external' GNUmakefile 2>/dev/null; then
              substituteInPlace GNUmakefile --replace-fail " -linkmode=external" ""
            fi
          '';
        });
      })
    ];
  };
}
