{ ... }:
{
  environment.variables = {
    COLORTERM = "truecolor";

    # set by modules/user/editor/neovim.nix
    # EDITOR = "nvim";
    # VISUAL = "nvim";

    LANG = "en_US-UTF-8";
    LC_ALL = "en_US.UTF-8";
    LC_CTYPE = "en_US.UTF-8";
  };
}
