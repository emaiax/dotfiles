{
  imports = [
    ./apps
    ./cli
    ./editor
    ./git
    ./packages
    ./shell
    ./sops
  ];

  # ensures ~/code folder exists
  #
  home.activation.createCodeDir = ''
    mkdir -p $HOME/code
  '';
}
