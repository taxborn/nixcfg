let
  commonExcludes = [
    # very large paths
    "/var/lib/docker"
    "/var/lib/systemd"
    "/var/lib/libvirt"

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
  services.borgbackup.jobs."helium-01-rsync" = {
    paths = [
      "/home"
      "/var/lib"
      "/etc"
    ];
    exclude = commonExcludes;
    repo = "ssh://de4388@de4388.rsync.net/./borg-repos/helium-01";
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

  services.borgbackup.jobs."helium-01-helium" = {
    paths = [
      "/home"
      "/var/lib"
      "/etc"
    ];
    exclude = commonExcludes;
    repo = "/mnt/hdd/borg-repos/helium-01";
    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat /root/borg/passphrase";
    };
    environment = {
      BORG_RSH = "ssh -i /root/borg/ssh_key";
    };
    extraCreateArgs = "--verbose --stats --list --checkpoint-interval 600";
    compression = "auto,zstd";
    startAt = "daily";
  };
}
