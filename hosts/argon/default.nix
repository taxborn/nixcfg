{ modulesPath, self, ... }:

{
  imports = [
    ./proxy.nix
    self.diskoConfigurations.btrfs-ovh
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  networking.hostName = "argon";
  system.stateVersion = "25.11";

  myNixOS = {
    profiles.server.enable = true;
    services.forgejo.runner.enable = true;
    services.monitoring.server.enable = true;

    services.backups.client = {
      enable = true;
      extraExcludes = [
        "/var/lib/prometheus2"
        "/var/lib/loki"
      ];
      sqliteDatabases.grafana = "/var/lib/grafana/data/grafana.db";
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
