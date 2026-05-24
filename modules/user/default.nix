{
  imports = [
    ./cli
    ./apps
    ./shell
    ./git
    ./packages
  ];

  # ensures ~/code folder exists
  #
  home.activation.createCodeDir = ''
    mkdir -p $HOME/code
  '';
}
