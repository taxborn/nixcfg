{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.tangled.spindle;
  networkMap = config.mySnippets.biscuits-at.networkMap;
  spindle = config.services.tangled.spindle;
in
{
  options.myNixOS.services.tangled.spindle.enable =
    lib.mkEnableOption "Tangled spindle, the CI runner behind spindle.biscuits.at";

  config = lib.mkIf cfg.enable {
    # Upstream's unit sets no `User=`, so the spindle runs as root, and the
    # module turns on rootful Docker for the nixery engine, whose socket is
    # root by another name. A workflow can therefore read anything on the
    # host, so CI stays off any host holding keys it could reach.
    assertions = [
      {
        assertion = !config.myNixOS.services.forgejo.enable;
        message = "Keep the spindle, which runs CI as root, off the host holding Forgejo's repositories and credentials.";
      }
      {
        assertion = !config.myNixOS.services.tangled.knot.enable;
        message = "Keep the spindle, which runs CI as root, off the host holding the knot's master key.";
      }
      {
        assertion = !config.myNixOS.services.backups.server.enable;
        message = "Keep CI jobs off the fleet's backup server.";
      }
    ];

    # The P-256 key the spindle signs with and publishes in its did:web
    # document. It never generates one. Agenix rather than a file made by hand
    # so a rebuilt host comes back as the same identity: a new key makes other
    # services distrust the spindle until they see the new document. agenix's
    # root-only 0400 default is right, since the spindle runs as root.
    age.secrets.tangledSpindleKey.file = "${self}/secrets/tangled/spindle-key.age";

    myNixOS.services.backups.client = lib.mkIf config.myNixOS.services.backups.client.enable {
      # Repository CI secrets live in here as plaintext, one reason it is
      # dumped through SQLite into the encrypted archive and not copied live.
      sqliteDatabases.spindle = spindle.server.dbPath;

      # /var/lib is a default backup path. Image layers and per-run clones are
      # rebuilt from the network and churn on every job, which borg would
      # otherwise archive on every run.
      extraExcludes = [
        "/var/lib/docker"
        spindle.server.repoDir
      ];
    };

    services.tangled.spindle = {
      enable = true;
      keyPath = config.age.secrets.tangledSpindleKey.path;
      contact.email = "atproto@biscuits.at";

      server = {
        hostname = networkMap.spindle.domain;
        inherit (config.myNixOS.services.tangled) owner;

        # Upstream binds every interface. Caddy is the way in.
        listenAddr = "127.0.0.1:${toString networkMap.spindle.port}";

        # The default, spelled out because it is the line between a private
        # runner and a public one: closed runs CI only for the owner and the
        # allow-list. Anyone who can run a workflow can read that repository's
        # secrets and reach whatever Carbon reaches, the tailnet included.
        admission = "closed";

        # One job at a time. Carbon also serves braxton.is, and a second
        # concurrent build would compete with it.
        maxJobCount = 1;
      };

      # Keep logs on disk under /var/log/spindle. Upstream defaults to an S3
      # bucket, which would need AWS credentials in an environment file.
      artifactStores.s3.bucket = "";

      pipelines = {
        # Upstream's five minutes covers the queue wait as well, which fails
        # most Nix builds.
        workflowTimeout = "1h";

        # Docker containers run outside the spindle's own unit, so these caps
        # are the only thing bounding a nixery job. Sized to leave room for
        # the website.
        nixery = {
          maxJobMemoryMb = 4096;
          maxConcurrentWorkflows = 1;
        };

        # One nixos-image workflow at a time. The image declares 4096 MiB and
        # 2 vCPUs, and the spindle charges each VM a further 96 MiB for its
        # runner process (`runnerBufferMiB`), so a cap of exactly 4096 fits no
        # VM at all. 4608 leaves headroom for that buffer without fitting two.
        microvm.limits.total = {
          memoryMiB = 4608;
          vcpus = 2;
        };
      };
    };

    # `image: nixos` for microvm workflows, the module's default image. The
    # directory has to exist before the link can be placed in it.
    systemd.tmpfiles.rules = [
      "d ${spindle.pipelines.microvm.imageDir} 0755 root root -"
      "L+ ${spindle.pipelines.microvm.imageDir}/nixos - - - - ${
        self.packages.${pkgs.stdenv.hostPlatform.system}.spindle-nixos-image
      }"
    ];
  };
}
