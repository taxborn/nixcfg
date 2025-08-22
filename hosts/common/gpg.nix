{ pkgs, ... }:

{
  services.udev = {
    packages = [ pkgs.yubikey-personalization ];
  };
  services.pcscd.enable = true;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
}
