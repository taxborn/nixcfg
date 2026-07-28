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
    programs.grub.enable = true;
    services = {
      backups.client = {
        enable = true;
        # Forgejo's cluster lives here.
        postgresqlDumpAll = true;
        extraExcludes = [
          # Bleve indexes. REPO_INDEXER_ENABLED makes these roughly the size of
          # the repository content again and they churn on every push, so they
          # would dominate each archive — and Forgejo rebuilds them on demand,
          # so there is nothing in them worth carrying off-site.
          "/var/lib/forgejo/data/indexers"
        ];
      };
      forgejo.enable = true;
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
