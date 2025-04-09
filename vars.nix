rec {
  users = {
    emaiax = {
      username = "emaiax";
      homeDirectory = "/Users/emaiax";
    };

    eduardo = {
      username = "eduardo.maia";
      homeDirectory = "/Users/eduardo.maia";
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
    M125356 = {
      hostname = "M125356";
      arch = "aarch64-darwin";
      user = users.eduardo;
    };
    M137516 = {
      hostname = "M137516";
      arch = "aarch64-darwin";
      user = users.eduardo;
    };
  };
}
