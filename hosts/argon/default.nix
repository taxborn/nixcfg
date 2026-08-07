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
        # Metrics and logs, and both are regenerable by definition: a TSDB
        # restored from last night is a gap-free record of a machine that no
        # longer exists. They are also by far the largest thing on this host and
        # the fastest changing, so they would dominate every archive and dedup
        # badly between them.
        "/var/lib/prometheus2"
        "/var/lib/loki"
      ];

      # Grafana's dashboards, datasources and admin password are all provisioned
      # from the store, so most of this database is reproducible — but
      # annotations, alert silences and per-user preferences are not, and they
      # live nowhere else. Dumping rather than copying for the reason the option
      # documents: borg reaches the `.db` and its `-wal` at different moments,
      # and a torn pair is what recovery would read.
      sqliteDatabases.grafana = "/var/lib/grafana/grafana.db";
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
