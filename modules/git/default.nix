{ pkgs, lib, ... }:
{
  home.file.".ssh/allowed_signers".text = ''
    * ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMTbZW/l0UNEFLwDKrEQGyc+pZGDCq85Nyy7P1JV9S2o
  '';

  home.packages = with pkgs; [
    git-lfs
  ];

  programs.git = {
    enable = true;

    delta.enable = true;
    lfs.enable = true;
    ignores = lib.splitString "\n" (builtins.readFile ./gitignore-global);

    userName = "Eduardo Maia";
    userEmail = "emaiax@users.noreply.github.com";

    aliases = {
      a = "add .";

      # commit and ammend
      ci = "commit -m";
      cia = "commit -s --amend --no-edit";

      co = "checkout";

      # grab a change from a branch and replay it 
      cp = "cherry-pick -x" ;

      # diff 
      df = "diff";          # unstaged changes
      dc = "diff --cached"; # staged changes

      # log
      lg = "log --oneline --decorate";

      # please = "push --force-with-lease";

      st = "status";

      undo = "reset --soft HEAD^1"; # undo last commit
      unstage = "restore --staged"; # unstage changes
    };
    extraConfig = {
      # sign commits with ssh key
      # https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key#telling-git-about-your-ssh-key
      #
      gpg.format = "ssh";
      tag.gpgSign = true;
      commit.gpgSign = true;
      user.signingkey = "~/.ssh/github.pub";
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";

      # core = {
      #   editor = "nvim";
      #   compression = -1;
      #   autocrlf = "input";
      #   whitespace = "trailing-space,space-before-tab";
      #   precomposeunicode = true;
      # };
      color = {
        diff = "auto";
        status = "auto";
        branch = "auto";
        ui = true;
      };
      advice = {
        addEmptyPathspec = false;
      };
      apply = {
        whitespace = "nowarn";
      };
      help = {
        autocorrect = 1;
      };
      grep = {
        extendRegexp = true;
        lineNumber = true;
      };
      push = {
        autoSetupRemote = true;
        default = "simple";
      };
      submodule = {
        fetchJobs = 4;
      };
      log = {
        showSignature = false;
      };
      format = {
        signOff = true;
      };
      rerere = {
        enabled = true;
      };
      pull = {
        ff = "only";
      };
      init = {
        defaultBranch = "main";
      };
    };
  };
}
