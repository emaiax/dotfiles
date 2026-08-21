{ config, pkgs, ... }:
{
  imports = [
    ./git.nix
    ./gh.nix
  ];

  home.packages = [ pkgs.forgejo-cli ];

  # fj's fallback host when cwd's git remote doesn't resolve one.
  programs.zsh.initContent = ''
    [[ -r "${config.sops.secrets.homelab-domain.path}" ]] &&
      export FJ_FALLBACK_HOST="https://forgejo.$(<"${config.sops.secrets.homelab-domain.path}")"
  '';
}
