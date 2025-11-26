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

  # https://github.com/starship/starship/issues/3418#issuecomment-2477375663
  # starship_zle-keymap-select-wrapped:1: maximum nested function level reached; increase FUNCNEST?
  #
  programs.zsh.initContent = ''
    if [[ "$${widgets[zle-keymap-select]#user:}" == "starship_zle-keymap-select" || \
          "$${widgets[zle-keymap-select]#user:}" == "starship_zle-keymap-select-wrapped" ]]; then
        zle -N zle-keymap-select "";
    fi
  '';
}
