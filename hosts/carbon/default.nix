{ modulesPath, self, ... }:

{
  imports = [
    self.diskoConfigurations.btrfs-ovh
    (modulesPath + "/profiles/qemu-guest.nix")
    ./proxy.nix
  ];

  networking.hostName = "carbon";
  system.stateVersion = "25.11";

  myNixOS = {
    profiles.server.enable = true;
    services = {
      backups.client = {
        enable = true;
        sqliteDatabases.forgejo = "/var/lib/forgejo/data/forgejo.db";
        extraExcludes = [
          "/var/lib/forgejo/data/indexers"
          # Build outputs, reproducible by re-running the job that produced
          # them, and the one part of Actions state large enough to bloat an
          # archive. Job logs are not excluded: they are compressed text and
          # they are the record of why a run failed.
          "/var/lib/forgejo/data/actions_artifacts"
        ];
      };
      forgejo = {
        enable = true;
        runners = {
          argon = { };
          helium = { };
        };
      };
      glance.enable = true;
      taxborn-com.enable = true;
      vaultwarden.enable = true;
    };
  };

  myHardware = {
    intel.cpu.enable = true;
    profiles.ovh = {
      enable = true;
      ipv6 = {
        enable = true;
        address = "2604:2dc0:202:300::236a";
        gateway = "2604:2dc0:202:300::1";
      };
    };
  };
}
