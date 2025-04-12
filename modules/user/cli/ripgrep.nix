{ ... }:
{
  programs.ripgrep = {
    enable = true;

    arguments = [
      # don't let ripgrep vomit really long lines to my terminal, and show a preview.
      "--max-columns=150"
      "--max-columns-preview"

      # search hidden files / directories (e.g. dotfiles) by default
      "--hidden"

      # using glob patterns to include/exclude files or folders
      "--glob=!.git/*"

      # set the colors
      "--colors=line:none"
      "--colors=line:style:bold"

      # use smart case
      "--smart-case"
    ];
  };
}
