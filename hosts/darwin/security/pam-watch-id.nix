{ ... }:
{
  security.pam.services.sudo_local = {
    enable = true;
    watchIdAuth = true;
  };
}
