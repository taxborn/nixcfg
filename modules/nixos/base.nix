{
  config,
  lib,
  pkgs,
  self,
  ...
}:

{
  options.myNixOS.base.enable = lib.mkEnableOption "base NixOS system configuration";

  config = lib.mkIf config.myNixOS.base.enable {
    home-manager.users.taxborn.imports = [ self.homeModules.profile-default ];

    age.identityPaths = lib.mkDefault [ "/etc/ssh/ssh_host_ed25519_key" ];

    networking.networkmanager.enable = true;

    catppuccin = {
      enable = true;
      autoEnable = true;
      flavor = "mocha";
      accent = "mauve";
    };

    myNixOS = {
      profiles = {
        btrfs.enable = true;
        swap.enable = true;
      };
      programs = {
        nix.enable = true;
        ssh.enable = true;
      };
      services = {
        tailscale.enable = true;
        monitoring.client.enable = lib.mkDefault true;
      };
    };

    services = {
      fstrim = {
        enable = true;
        interval = "monthly";
      };
      smartd = {
        enable = lib.mkDefault true;
        autodetect = true;
      };
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
        self.inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
        btop
        wget
        git
        vim
      ];
    };

    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
    time.timeZone = lib.mkDefault "America/Chicago";
    system.configurationRevision = self.rev or self.dirtyRev or null;
    hardware.enableRedistributableFirmware = lib.mkDefault true;
  };
}
