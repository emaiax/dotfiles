{ config, ... }:
{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    # caches `use flake` shells and registers them as GC roots
    nix-direnv.enable = true;
  };
}
