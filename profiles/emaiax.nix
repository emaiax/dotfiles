{ ... }:
{
  home.sessionVariables = {
    COLORTERM = "truecolor";

    EDITOR = "nvim";
    VISUAL = "nvim";

    LC_ALL = "en_US.UTF-8";
    LC_CTYPE = "en_US.UTF-8";
  };

  imports = [
    ../modules/ssh.nix
    ../modules/shell.nix
    ../modules/vscode
    ../modules/git
    ../modules/bat
  ];
}
