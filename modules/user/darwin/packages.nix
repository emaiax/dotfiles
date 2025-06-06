{ pkgs, ... }:
{
  # This is a list of packages that will be installed in the user's profile.
  # They are installed via home-manager.
  #
  home.packages = with pkgs; [
    arc-browser # better browser
    code-cursor # cursor ide
    docker # docker cli
    docker-compose # docker compose cli
    lmstudio # local and open-source LLMs
  ];
}
