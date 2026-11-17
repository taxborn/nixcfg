{
  config,
  pkgs,
  self,
  ...
}:
let
  networkMap = config.homelab.services;
  spindle = config.services.tangled.spindle;
in
{
  # The spindle runs CI as root, so it stays off hosts holding keys it could reach.
  assertions = [
    {
      assertion = !config.services.tangled.knot-rs.enable;
      message = "Keep the spindle, which runs CI as root, off the host holding the knot's master key.";
    }
    {
      assertion = config.networking.hostName != config.homelab.backupServer.host;
      message = "Keep CI jobs off the fleet's backup server.";
    }
  ];

  age.secrets.tangledSpindleKey.file = "${self}/secrets/tangled/spindle-key.age";

  homelab.backups = {
    # Holds repository CI secrets in plaintext.
    sqliteDatabases.spindle = spindle.server.dbPath;

    extraExcludes = [
      "/var/lib/docker"
      spindle.server.repoDir
    ];
  };

  services.tangled.spindle = {
    enable = true;
    keyPath = config.age.secrets.tangledSpindleKey.path;
    contact.email = config.homelab.mail.atproto;

    server = {
      hostname = networkMap.spindle.domain;
      owner = config.homelab.owner.did;

      listenAddr = "127.0.0.1:${toString networkMap.spindle.port}";

      # Closed: anyone who can run a workflow can read its secrets and reach the tailnet.
      admission = "closed";

      maxJobCount = 1;
    };

    artifactStores.s3.bucket = "";

    pipelines = {
      workflowTimeout = "1h";

      nixery = {
        maxJobMemoryMb = 4096;
        maxConcurrentWorkflows = 1;
      };

      microvm.limits.total = {
        memoryMiB = 4608;
        vcpus = 2;
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d ${spindle.pipelines.microvm.imageDir} 0755 root root -"
    "L+ ${spindle.pipelines.microvm.imageDir}/nixos - - - - ${
      self.packages.${pkgs.stdenv.hostPlatform.system}.spindle-nixos-image
    }"
  ];
}
