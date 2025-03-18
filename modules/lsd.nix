{ ... }:
{
  programs.lsd = {
    enable = true;
    enableAliases = true;

    # aliases = {
    #   ls = "${pkgs.lsd}/bin/lsd";
    #   ll = "${pkgs.lsd}/bin/lsd -l";
    #   la = "${pkgs.lsd}/bin/lsd -A";
    #   lt = "${pkgs.lsd}/bin/lsd --tree";
    #   lla = "${pkgs.lsd}/bin/lsd -lA";
    #   llt = "${pkgs.lsd}/bin/lsd -l --tree";
    # };
  };
}
