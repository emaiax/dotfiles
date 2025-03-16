{ ... }:
{
  # do not change!
  home.stateVersion = "25.05";

  # let home-manager manage itself
  programs.home-manager.enable = true;

  home.homeDirectory = "/Users/emaiax";

  home.sessionVariables = {
    COLORTERM = "truecolor";

    EDITOR = "nvim";
    VISUAL = "nvim";

    LC_ALL = "en_US.UTF-8";
    LC_CTYPE = "en_US.UTF-8";
  };
}
