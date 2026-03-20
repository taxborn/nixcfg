{
  config,
  lib,
  ...
}:
{
  options.myNixOS.services.hash-haus.enable = lib.mkEnableOption "hash.haus leaderboard";

  config = lib.mkIf config.myNixOS.services.hash-haus.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/hash-haus 0750 root root -"
    ];

    virtualisation.oci-containers = {
      backend = "podman";

      containers = {
        hash-haus = {
          extraOptions = [ "--pull=always" ];
          image = "git.mischief.town/taxborn/hash.haus";
          ports = [ "${toString config.mySnippets.mischief-town.networkMap.hash-haus.port}:4321" ];
          volumes = [ "/var/lib/hash-haus:/data" ];
          environment = {
            DATABASE_PATH = "/data/hash.haus.db";
            SITE_URL = "https://hash.haus";
          };
        };
      };
    };

    myNixOS.programs.podman.enable = true;
  };
}
