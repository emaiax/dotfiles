{ ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;

    # aliases
    viAlias = true;
    vimAlias = true;

    # language support
    withNodeJs = true;
    withPython3 = true;
    withRuby = true;
  };
}
