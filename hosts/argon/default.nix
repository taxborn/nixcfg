{ modulesPath, self, ... }:

{
  imports = [
    self.diskoConfigurations.btrfs-ovh
    (modulesPath + "/profiles/qemu-guest.nix")
    ./proxy.nix
  ];

  networking.hostName = "argon";
  system.stateVersion = "25.11";

  myNixOS = {
    profiles.server.enable = true;
    services = {
      backups.client = {
        enable = true;

        # Tranquil's repository store. A logical dump rather than the live data
        # directory, for the reason the option documents — and it is the whole
        # instance: every account's repo, its encrypted signing key, and the
        # firehose sequence live in postgres. Blobs are not in here; they sit
        # under /var/lib/tranquil-pds/blobs and ride along in the archive.
        postgresqlDumpAll = true;
      };
      forgejo.enable = true;
      glance.enable = true;
      tranquil-pds.enable = true;
      vaultwarden.enable = true;
    };
  };

  myHardware = {
    intel.cpu.enable = true;
    profiles.ovh = {
      enable = true;
      # OVH gives this instance a second NIC for IPv6; ens3 keeps IPv4.
      ipv6 = {
        enable = true;
        interface = "ens4";
        address = "2604:2dc0:101:200::2cc6";
        gateway = "2604:2dc0:101:200::1";
        ipv4Method = "disabled";
      };
    };
  };
}
