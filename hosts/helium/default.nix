{ self, ... }:

{
  imports = [
    ./disko.nix
    ./external-hdd.nix
    ./proxy.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "helium";
  system.stateVersion = "25.11";

  # Minecraft, for friends. The one deliberate public port outside Caddy, and
  # no module in this repo serves it, so nothing here binds or proxies it.
  networking.firewall.allowedTCPPorts = [ 25565 ];
  networking.firewall.allowedUDPPorts = [ 25565 ];

  myNixOS = {
    profiles.server.enable = true;
    programs.systemd-boot.enable = true;
    services = {
      paperless.enable = true;

      backups = {
        client = {
          enable = true;
          notify.enable = true;
        };
        server = {
          enable = true;
          authorizedKeys = {
            argon = builtins.readFile "${self}/secrets/borg/argon/ssh_key.pub";
            carbon = builtins.readFile "${self}/secrets/borg/carbon/ssh_key.pub";
            tungsten = builtins.readFile "${self}/secrets/borg/tungsten/ssh_key.pub";
            uranium = builtins.readFile "${self}/secrets/borg/uranium/ssh_key.pub";
          };
        };
      };
    };
  };

  myHardware.intel.cpu.enable = true;

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "nvme"
      "usb_storage"
      "sd_mod"
      "rtsx_pci_sdmmc"
    ];

    loader.timeout = 0;
  };
}
