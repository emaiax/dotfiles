{ pkgs, ... }:
{
  # This file contains the list of packages to be installed on all hosts.
  # It installs the packages in the system environment (available for all users).
  #
  environment.systemPackages = with pkgs; [
    asdf-vm          # programming languages version manager
    btop             # better top
    curl             # command line tool for transferring data with URLs
    go               # go programming language
    jq               # command-line JSON processor
    just             # command runner, similar to make
    neovim           # vim on steroids
    nixfmt-rfc-style # format nix files in RFC style
    tlrc             # command line tool for managing TL;DR pages
    unixtools.watch  # watch command for running a program periodically
    wget             # command line tool for downloading files from the web
  ];
}
