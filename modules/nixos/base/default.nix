{ config, lib, pkgs, self, ... }:

{
  options.myNixOS.base.enable = lib.mkEnableOption "base NixOS system configuration";

  config = lib.mkIf config.myNixOS.base.enable {
    networking.networkmanager.enable = true;

    myNixOS.profiles.swap.enable = true;

    services = {
      fstrim.enable = true;
      openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };
    };

    environment = {
      etc."nixos".source = self;
      systemPackages = with pkgs; [
        btop
        wget
        tmux
        neovim
      ];
    };

    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
    time.timeZone = lib.mkDefault "America/Chicago";
    system.configurationRevision = self.rev or self.dirtyRev or null;
    hardware.enableRedistributableFirmware = lib.mkDefault true;
  };
}
