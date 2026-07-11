{ config, pkgs, ... }:
{
  imports = [
    ./git.nix
    ./gh.nix
  ];

  home.packages = [ pkgs.forgejo-cli ];

  # fj resolves its instance from the cwd's git remote; this is the
  # fallback everywhere else. The URL is private, so it comes from a
  # sops secret read at shell startup instead of a nix-store literal.
  sops.secrets.fj-fallback-host = { };

  programs.zsh.initContent = ''
    [[ -r "${config.sops.secrets.fj-fallback-host.path}" ]] &&
      export FJ_FALLBACK_HOST="$(<"${config.sops.secrets.fj-fallback-host.path}")"
  '';
}
