{
  config,
  lib,
  pkgs,
  self,
  ...
}:
{
  imports = [
    ./btrfs.nix
    ./fleet.nix
    ./nix.nix
    ./ssh.nix
    ./swap.nix
    ./user.nix
    ../services/backups
    ../services/monitoring/client.nix
    ../services/tailscale.nix
  ];

  home-manager.users.${config.homelab.owner.username}.imports = [ ../../home ];

  age.identityPaths = lib.mkDefault [ "/etc/ssh/ssh_host_ed25519_key" ];

  networking.networkmanager.enable = true;

  catppuccin = {
    accent = "mauve";
    autoEnable = true;
    cache.enable = true;
    enable = true;
    flavor = "mocha";
  };

  services = {
    fstrim = {
      enable = true;
      interval = "monthly";
    };
    # mkDefault so the OVH module can turn it off.
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

  boot.kernel.sysctl = {
    # One-way until reboot.
    "kernel.kexec_load_disabled" = true;

    "kernel.kptr_restrict" = 2;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
  };

  systemd.services.nscd.unitConfig.StartLimitIntervalSec = 0;

  environment = {
    etc."nixos".source = self;
    systemPackages = with pkgs; [
      self.packages.${pkgs.stdenv.hostPlatform.system}.agenix
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

  boot.kernelModules = [ "kvm-intel" ];
  hardware.cpu.intel.updateMicrocode = config.hardware.enableRedistributableFirmware;

}
