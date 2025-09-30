let
  commonExcludes = [
    # very large paths
    "/var/lib/docker"
    "/var/lib/systemd"

    # temporary files created by cargo and others
    "**/target"
    "*.pyc"
    "*.o"
    "*/node_modules/*"

    # caches
    "/home/*/.cache"
    "/home/*/.cargo"
    "/home/*/.npm"
  ];
in
{
  services.borgbackup.jobs."carbon-rsync" = {
    paths = [
      "/home"
      "/var/lib"
      "/etc"
    ];
    exclude = commonExcludes;
    repo = "ssh://de4388@de4388.rsync.net/./borg-repos/carbon";
    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat /root/borg/passphrase";
    };
    environment = {
      BORG_RSH = "ssh -i /root/borg/ssh_key";
      BORG_REMOTE_PATH = "borg14"; # an rsync.net thing
    };
    extraCreateArgs = "--verbose --stats --list --checkpoint-interval 600";
    compression = "auto,zstd";
    startAt = "daily";
  };

  # services.borgbackup.jobs."carbon-helium" = {
  #   paths = [
  #     "/home"
  #     "/var/lib"
  #     "/etc"
  #   ];
  #   exclude = commonExcludes;
  #   repo = "ssh://taxborn@100.64.1.0//mnt/hdd/borg-repos/carbon";
  #   encryption = {
  #     mode = "repokey-blake2";
  #     passCommand = "cat /root/borg/passphrase";
  #   };
  #   environment = {
  #     BORG_RSH = "ssh -i /root/borg/ssh_key";
  #   };
  #   extraCreateArgs = "--verbose --stats --list --checkpoint-interval 600";
  #   compression = "auto,zstd";
  #   startAt = "daily";
  # };
}
