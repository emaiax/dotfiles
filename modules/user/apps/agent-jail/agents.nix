{
  claude = {
    cmd = [
      "npx"
      "-y"
      "@anthropic-ai/claude-code"
    ];
    cacheVolume = "agent-jail-npm-cache-claude";
    mounts = [
      {
        host = "$HOME/.claude";
        container = "/root/.claude";
      }
      {
        host = "$HOME/.claude.json";
        container = "/root/.claude.json";
      }
    ];
  };
  opencode = {
    cmd = [
      "npx"
      "-y"
      "opencode-ai"
    ];
    cacheVolume = "agent-jail-npm-cache-opencode";
    mounts = [
      {
        host = "$HOME/.config/opencode";
        container = "/root/.config/opencode";
      }
      {
        host = "$HOME/.local/share/opencode";
        container = "/root/.local/share/opencode";
      }
    ];
  };
}
