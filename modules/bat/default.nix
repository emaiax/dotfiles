{ config, ... }:
{
  xdg.configFile."bat/syntaxes/ghostty.sublime-syntax" = {
    enable = true;
    source = ./ghostty.sublime-syntax;
  };

  programs.bat = {
    enable = true;

    config = {
      style = "changes,header-filename,header-filesize,grid,numbers";
    };

    config.map-syntax = [ "${config.xdg.configHome}/ghostty/config:Ghostty Config" ];
  };
}
