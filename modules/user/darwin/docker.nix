{ pkgs, ... }:
{
  home.packages = with pkgs; [
    docker         # docker cli
    docker-compose # docker compose cli
  ];
}
