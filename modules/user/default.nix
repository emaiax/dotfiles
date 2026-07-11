{
  imports = [
    ./cli
    ./apps
    ./shell
    ./git
    ./packages
    ./sops
  ];

  # ensures ~/code folder exists
  #
  home.activation.createCodeDir = ''
    mkdir -p $HOME/code
  '';
}
