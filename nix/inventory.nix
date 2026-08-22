rec {
  users = {
    emaiax = {
      username = "emaiax";
      homeDirectory = "/Users/emaiax";

      # Relative to homeDirectory. The main checkout, always, not whatever worktree a module happens to be
      # evaluated from: modules that need a live, writable, out-of-store file (vscode/settings.json,
      # iterm2/config, claudio/AGENTS.md) symlink here instead of into the read-only nix store.
      dotfilesCheckout = "code/dotfiles";
    };
  };

  # auto-scales when new hosts are added
  hosts = {
    dudumini = {
      hostname = "dudumini";
      arch = "x86_64-darwin";
      user = users.emaiax;
    };
    dudupro = {
      hostname = "dudupro";
      arch = "aarch64-darwin";
      user = users.emaiax;
    };
  };
}
