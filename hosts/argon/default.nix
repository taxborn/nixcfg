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
    services.monitoring.server.enable = true;

    # This host builds the fleet — see .forgejo/workflows/build.yaml — and it is
    # also where the whole monitoring stack lives. One run at a time, boxed into
    # roughly three quarters of the machine, so a build cannot starve Prometheus
    # and Loki of the memory they need to keep recording that it happened.
    #
    # Capacity is 1 rather than the default 3 because the limits below are per
    # container: three of them would claim 36g on a 16 GB host. Queueing the
    # second push is the wanted behaviour anyway — two runs would contend for
    # the same store and build the same derivations twice.
    services.forgejo.runner = {
      enable = true;
      capacity = 1;
      containerOptions = [
        "--memory=12g"
        "--cpus=6"
      ];
    };

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
