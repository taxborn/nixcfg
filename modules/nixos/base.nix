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

    myNixOS = {
      profiles.swap.enable = true;
      programs.nix.enable = true;
      services.tailscale.enable = true;
    };

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
        self.inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
        btop
        wget
        git
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
