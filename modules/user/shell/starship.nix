{ ... }:
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      # scan_timeout = 50;
      command_timeout = 1000;
    };
  };
}
