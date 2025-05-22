{ ... }:
{
  programs.zed-editor = {
    enable = true;

    extensions = [
      "elixir"
      "javascript"
      "just"
      "ruby"
      "rust"
      "typescript"
      "zig"
    ];

    userSettings = {
      ui_font_size = 16;
      buffer_font_size = 16;

      theme = {
        mode = "system";
        light = "One Light";
        dark = "One Dark";
      };

      vim_mode = true;

      telemetry = {
        metrics = false;
      };
    };
  };
}
