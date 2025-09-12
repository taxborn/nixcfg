{ pkgs, ... }:

{
  services.udev = {
    packages = [ pkgs.yubikey-personalization ];
  };
  services.pcscd.enable = true;

  environment.systemPackages = with pkgs; [
    yubikey-manager
  ];

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
}
