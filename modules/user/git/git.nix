{ pkgs, lib, ... }:
{
  home.file.".ssh/allowed_signers".text = ''
    * ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMTbZW/l0UNEFLwDKrEQGyc+pZGDCq85Nyy7P1JV9S2o
    * ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAThvvZjzCVQw5OVznRb/xvWN/bGMAmfdyDGdISZPips
    * ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLMC5il0Ji5XzSEzIylvAKwfNt0iRprU1i0igVfa69l
    * ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM/6f4x2IMtnHjZNr2dvNgiywZhVhhUOvst2zsw3xoOr
  '';

  home.packages = with pkgs; [
    git-lfs
  ];

  programs.git = {
    enable = true;

    lfs.enable = true;
    ignores = lib.splitString "\n" (builtins.readFile ./gitignore-global);

    settings = {
      user = {
        name = "Eduardo Maia";
        email = "emaiax@users.noreply.github.com";
        signingKey = "~/.ssh/github.pub";
      };

      # sign commits with ssh key
      # https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key#telling-git-about-your-ssh-key
      #
      commit.gpgSign = true;
      gpg.allowedSignersFile = "~/.ssh/allowed_signers";
      gpg.format = "ssh";
      tag.gpgSign = true;

      # other settings
      #
      advice.addEmptyPathspec = false;
      apply.whitespace = "nowarn";
      format.signOff = true;
      help.autocorrect = 1;
      init.defaultBranch = "main";
      log.showSignature = true;
      rerere.enabled = true;
      submodule.fetchJobs = 4;

      color = {
        diff = "auto";
        status = "auto";
        branch = "auto";
        ui = true;
      };

      grep = {
        extendRegexp = true;
        lineNumber = true;
      };

      pull = {
        rebase = true;
      };

      push = {
        autoSetupRemote = true;
        default = "simple";
      };

      alias = {
        a = "add .";

        # commit and ammend
        ci = "commit -m";
        cia = "commit -s --amend --no-edit";

        co = "checkout";

        # grab a change from a branch and replay it
        cp = "cherry-pick -x";

        # diff
        df = "diff"; # unstaged changes
        dc = "diff --cached"; # staged changes

        # log
        lg = "log --oneline --decorate -20";

        # please = "push --force-with-lease";

        st = "status";

        undo = "reset --soft HEAD^1"; # undo last commit
        unstage = "restore --staged"; # unstage changes
      };
    };
  };
}
