{
  config,
  lib,
  pkgs,
  self,
  ...
}:
{
  options.myNixOS.base = {
    enable = lib.mkEnableOption "base system configuration";
  };

  config = lib.mkIf config.myNixOS.base.enable {
    console.useXkbConfig = true;

    environment = {
      etc."nixos".source = self;

      systemPackages = with pkgs; [
        self.inputs.agenix.packages.${pkgs.system}.default
        wget
      ];

      variables = {
        inherit (config.myNixOS) FLAKE;
        NH_FLAKE = config.myNixOS.FLAKE;
      };
    };

    hardware = {
      keyboard.qmk.enable = true;
      logitech.wireless.enable = true;
      enableRedistributableFirmware = lib.mkDefault true;
    };

    programs = {
      dconf.enable = true;
      git.enable = true;
      htop.enable = true;
    };

    networking.networkmanager.enable = true;

    system.configurationRevision = self.rev or self.dirtyRev or null;

    myNixOS = {
      profiles = {
        bluetooth.enable = true;
        performance.enable = true;
        swap.enable = true;
      };

      services.openssh.enable = true;
    };
  };
}
