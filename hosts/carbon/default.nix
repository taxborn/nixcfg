{
  self,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    ./home.nix
    ./secrets.nix

    self.diskoConfigurations.btrfs-carbon
    self.nixosModules.locale-en-us

    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  services.caddy = {
    virtualHosts."mischief.town".extraConfig = ''
      redir https://www.mischief.town{uri} permanent
    '';
  };
  services.caddy = {
    virtualHosts."taxborn.com".extraConfig = ''
      redir https://www.taxborn.com{uri} permanent
    '';
    virtualHosts."www.taxborn.com".extraConfig = ''
      respond "Hello, World!"
    '';

    virtualHosts."braxtonfair.com".extraConfig = ''
      redir https://www.braxtonfair.com{uri} permanent
    '';
    virtualHosts."www.braxtonfair.com".extraConfig = ''
      redir https://www.taxborn.com{uri} permanent
    '';
  };

  networking.hostName = "carbon";
  time.timeZone = "America/Chicago";
  system.stateVersion = "25.11";

  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];
  environment.systemPackages = with pkgs; [
    jdk21_headless
  ];

  myNixOS = {
    base.enable = true;
    profiles.btrfs.enable = true;
    programs = {
      nix.enable = true;
    };
    services = {
      tailscale = {
        enable = true;
        operator = "taxborn";
      };
      backups = {
        enable = true;
        repository = "ssh://de4388@de4388.rsync.net/./borg-repos/carbon";
      };
      glance.enable = true;
      forgejo.enable = true;
      vaultwarden.enable = true;
      caddy.enable = true;
    };
  };

  myHardware = {
    intel.cpu.enable = true;
    profiles.ssd.enable = true;
  };

  myUsers.taxborn = {
    enable = true;
    password = "$y$j9T$23GUNNxavO/S4n8DLkfs71$ShByJUJ9XCvIs2PLYmlAjenOtpcFvnSgshjbClEKB18";
  };

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "virtio_pci"
    "virtio_scsi"
  ];

  # TODO: Figure out a way to not have this have to be defined on carbon?
  # Move to tailnet
  services.caddy.virtualHosts."docs.mischief.town".extraConfig =
    ''reverse_proxy http://100.64.1.0:21594'';
}
