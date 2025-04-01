{ config, ... }:
{
  programs.bat = {
    enable = true;

    config = {
      style = "changes,header-filename,header-filesize,grid,numbers";
    };
  };
}
