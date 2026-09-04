{
  config,
  pkgs,
  lib,
  ...
}:
let
  claudioDir = "${config.home.homeDirectory}/.local/share/claudio";
  identityBinDir = "${claudioDir}/identity-bin";
  gitIdentityConfigPath = "${claudioDir}/git-identity.gitconfig";
  fjIdentityHome = "${claudioDir}/fj-identity";
  ghIdentityConfigDir = "${claudioDir}/gh-identity";

  mkIdentityWrapper =
    {
      name,
      activeExec,
      passiveExec,
    }:
    pkgs.writeShellScript name ''
      if [[ -n "''${CLAUDIO_THEBOT_SESSION:-}" ]]; then
        exec ${activeExec} "$@"
      else
        exec ${passiveExec} "$@"
      fi
    '';
in
{
  home.sessionPath = [ identityBinDir ];

  home.file = {
    ".local/share/claudio/git-identity.gitconfig".text = ''
      [user]
      	name = claudio-thebot
      	email = claudio-thebot@users.noreply.github.com
      	signingkey = ~/.ssh/claudio-codes.pub

      [gpg]
      	format = ssh

      [commit]
      	gpgsign = true
    '';

    ".local/share/claudio/identity-bin/git" = {
      source = mkIdentityWrapper {
        name = "claudio-identity-git";
        activeExec = "${pkgs.git}/bin/git -c include.path=${gitIdentityConfigPath}";
        passiveExec = "${pkgs.git}/bin/git";
      };
      executable = true;
    };

    ".local/share/claudio/identity-bin/fj" = {
      source = mkIdentityWrapper {
        name = "claudio-identity-fj";
        activeExec = "env HOME=${fjIdentityHome} ${pkgs.forgejo-cli}/bin/fj";
        passiveExec = "${pkgs.forgejo-cli}/bin/fj";
      };
      executable = true;
    };

    ".local/share/claudio/identity-bin/gh" = {
      source = mkIdentityWrapper {
        name = "claudio-identity-gh";
        activeExec = "env GH_CONFIG_DIR=${ghIdentityConfigDir} ${pkgs.gh}/bin/gh";
        passiveExec = "${pkgs.gh}/bin/gh";
      };
      executable = true;
    };
  };
}
