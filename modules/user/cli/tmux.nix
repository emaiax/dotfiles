{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;

    keyMode = "vi";
    shortcut = "w";

    baseIndex = 1;
    clock24 = true;
    escapeTime = 500;
    historyLimit = 10000;
    mouse = true;
    reverseSplit = true;

    sensibleOnTop = true; # https://github.com/tmux-plugins/tmux-sensible

    extraConfig = ''
      set -g renumber-windows "on"     # renumber all windows when any window is closed
      set -g set-clipboard "on"        # use system clipboard
      set -g status-position "top"     # macOS / darwin style

      source-file ~/.config/tmux/catppuccin-config.tmux
    '';

    plugins = with pkgs.tmuxPlugins; [
      # plugins
      #
      cpu
      battery

      # tmux-ctrlw # https://github.com/eraserhd/tmux-ctrlw
      tmux-fzf # https://github.com/sainnhe/tmux-fzf
      # tmux-primary-ip # https://github.com/dreknix/tmux-primary-ip

      {
        plugin = vim-tmux-navigator; # https://github.com/christoomey/vim-tmux-navigator
        extraConfig = ''
          set -g @vim_navigator_mapping_left "C-h C-Left"      # use C-h and C-Left
          set -g @vim_navigator_mapping_right "C-l C-Right"    # use C-l and C-Right
          set -g @vim_navigator_mapping_up "C-k C-Up"          # use C-k and C-Up
          set -g @vim_navigator_mapping_down "C-j C-Down"      # use C-j and C-Down
        '';
      }
      {
        plugin = resurrect; # https://github.com/tmux-plugins/tmux-resurrect
        extraConfig = ''
          set -g @resurrect-strategy-vim "session"
          set -g @resurrect-strategy-nvim "session"
          set -g @resurrect-capture-pane-contents "on"
        '';
      }
      {
        plugin = continuum; # https://github.com/tmux-plugins/tmux-continuum
        extraConfig = ''
          set -g @continuum-boot "on"
          set -g @continuum-restore "on"
          set -g @continuum-save-interval "10" # minutes
        '';
      }
      # themes
      #
      # onedark-theme # https://github.com/odedlaz/tmux-onedark-theme
      # tokyo-night-tmux # https://github.com/janoamaral/tokyo-night-tmux
      # gruvbox # https://github.com/morhetz/gruvbox
      #
      {
        # https://github.com/tmux/tmux/wiki/Formats#basic-use
        # https://github.com/catppuccin/tmux
        plugin = catppuccin;
        extraConfig = ''
          # Configure the catppuccin plugin
          set -g @catppuccin_flavor "mocha"
          set -g @catppuccin_window_status_style "rounded"
          set -g @catppuccin_status_background "#242638"

          set -g @catppuccin_directory_text "#{b:pane_current_path}"
          set -g @catppuccin_window_text " #{b:pane_current_path}"
          set -g @catppuccin_window_current_text " #{b:pane_current_path}"
        '';
      }
    ];
  };
}
