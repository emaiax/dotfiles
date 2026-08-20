{ config, pkgs, ... }:
{
  imports = [
    ./git.nix
    ./gh.nix
  ];

  home.packages = [ pkgs.forgejo-cli ];

  # fj resolves its instance from the cwd's git remote; this is the fallback everywhere else.
  # Derived from the homelab-domain sops secret (modules/user/sops/default.nix) rather than its
  # own secret — forgejo's URL is just that domain under a fixed subdomain, confirmed against the
  # actual secret value before dropping the separate one. Reads the secret file directly instead
  # of depending on sops/default.nix's own HOMELAB_DOMAIN export, since programs.zsh.initContent
  # concatenates across modules with no guaranteed ordering between them.
  programs.zsh.initContent = ''
    [[ -r "${config.sops.secrets.homelab-domain.path}" ]] &&
      export FJ_FALLBACK_HOST="https://forgejo.$(<"${config.sops.secrets.homelab-domain.path}")"
  '';
}
