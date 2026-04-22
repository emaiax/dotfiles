{ pkgs, ... }:
{
  # This is a list of packages that will be installed in the user's profile.
  # They are installed via home-manager.
  #
  home.packages = with pkgs; [
    # bruno # http client for testing APIs
    docker # docker cli
    docker-compose # docker compose cli
    # lmstudio # local and open-source LLMs
    # ngrok # ngrok tunnel for local development
    # ollama # local LLMs
    uv # python package manager (used for Obsidian MCP in Cursor)
  ];
}
