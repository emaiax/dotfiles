{
  config,
  pkgs,
  lib,
  ...
}:
let
  identityBinDir = ".local/share/claudio/identity-bin";
  gitIdentityConfigPath = "${config.home.homeDirectory}/.claudio-git-identity.gitconfig";
  fjIdentityHome = "${config.home.homeDirectory}/.claudio-fj-identity";
  ghIdentityConfigDir = "${config.home.homeDirectory}/.claudio-gh-identity";

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
  home.sessionPath = [ "${config.home.homeDirectory}/${identityBinDir}" ];

  home.file = {
    ".claudio-git-identity.gitconfig".text = ''
      [user]
      	name = claudio-thebot
      	email = claudio-thebot@users.noreply.github.com
      	signingkey = ~/.ssh/claudio-codes.pub

      [gpg]
      	format = ssh

      [commit]
      	gpgsign = true
    '';

    "${identityBinDir}/git" = {
      source = mkIdentityWrapper {
        name = "claudio-identity-git";
        activeExec = "${pkgs.git}/bin/git -c include.path=${gitIdentityConfigPath}";
        passiveExec = "${pkgs.git}/bin/git";
      };
      executable = true;
    };

    "${identityBinDir}/fj" = {
      source = mkIdentityWrapper {
        name = "claudio-identity-fj";
        activeExec = "env HOME=${fjIdentityHome} ${pkgs.forgejo-cli}/bin/fj";
        passiveExec = "${pkgs.forgejo-cli}/bin/fj";
      };
      executable = true;
    };

    "${identityBinDir}/gh" = {
      source = mkIdentityWrapper {
        name = "claudio-identity-gh";
        activeExec = "env GH_CONFIG_DIR=${ghIdentityConfigDir} ${pkgs.gh}/bin/gh";
        passiveExec = "${pkgs.gh}/bin/gh";
      };
      executable = true;
    };
  };
}
