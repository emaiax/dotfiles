rec {
  users = {
    emaiax = {
      username = "emaiax";
      homeDirectory = "/Users/emaiax";
      repo = "code/dotfiles";
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
