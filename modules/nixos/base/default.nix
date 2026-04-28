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
        self.inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
        pkgs.age-plugin-yubikey
        btop
        just
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
    };

    networking.networkmanager = {
      enable = true;
      settings.keyfile.path = "/var/lib/NetworkManager/system-connections";
    };

    security.sudo.extraConfig = "Defaults lecture = never";

    # Bound persistent journal so boot/log-shippers don't replay months of
     # history and so disk usage stays predictable. ForwardToWall off to
     # skip a wall(1) write per emergency-level line.
    services.journald.extraConfig = ''
      SystemMaxUse=500M
      SystemKeepFree=1G
      MaxRetentionSec=2week
      ForwardToWall=no
    '';

    system.configurationRevision = self.rev or self.dirtyRev or null;

    myNixOS = {
      programs.neovim.enable = true;

      profiles = {
        bluetooth.enable = true;
        performance.enable = true;
        swap.enable = true;
      };

      services.openssh.enable = true;
    };
  };
}
