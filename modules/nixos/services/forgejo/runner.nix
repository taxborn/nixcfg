{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.forgejo.runner;
  networkMap = config.mySnippets.mischief-town.networkMap;

  user = "forgejo-runner";
  stateDir = "/var/lib/${user}";
  runtimeDir = "/run/${user}";
  configFile = "${runtimeDir}/config.yaml";

  # Rootless Podman's API socket lives under the runner user's own runtime
  # directory rather than /run/podman, so it cannot be named at build time
  # without pinning a uid. Every consumer below computes it from `id -u`.
  socketPath = "/run/user/$(id -u)/podman/podman.sock";

  # A Podman named volume holding /nix across jobs, so a workflow that builds a
  # NixOS closure does not re-fetch it from cache.nixos.org on every run. On
  # first mount the volume is empty and Podman copies the image's own /nix into
  # it; from then on the image's copy is masked by whatever the volume has
  # accumulated.
  #
  # That masking is why the image reference is in the name. Bumping `nixImage`
  # with a fixed volume name would leave every job running the *old* Nix out of
  # the volume, because there is nothing left to copy up into — a silent no-op
  # rather than an error. Deriving the name means a bump starts a fresh store,
  # and the stale volume is left behind for `podman volume rm` to reclaim.
  #
  # Nothing running inside a job may garbage-collect this store while `capacity`
  # is above 1, and the reason is not obvious. Nix protects an in-flight build's
  # paths with a temporary root at `/nix/var/nix/temproots/<pid>`, and deletes
  # any file it finds there on the grounds that "there can be no two processes
  # with the same pid" (src/libstore/gc.cc). Concurrent jobs are separate
  # containers with separate pid namespaces, all counting up from 1 through the
  # same sequence of steps, so two builds landing on one pid is ordinary rather
  # than unlucky — and the second one deletes the first's roots, leaving a
  # collector free to delete paths a live build is standing on.
  #
  # Builds alone are fine: the SQLite database and the per-path lock files are
  # keyed on inodes, which cross namespaces correctly. It is only collection
  # that breaks. So the store grows, and is reclaimed from outside a job, with
  # the runner stopped — `just runner-gc <host>`.
  nixStoreVolume = "forgejo-nix-store-${
    lib.replaceStrings [ "/" ":" "." ] [ "-" "-" "-" ] (lib.toLower cfg.nixImage)
  }";

  settingsFormat = pkgs.formats.yaml { };

  baseSettings = {
    log = {
      # What this host's journal gets.
      level = "info";
      # What is shipped to Forgejo and shown in the job's web view. Anything
      # more verbose puts runner internals in front of whoever reads the run.
      job_level = "info";
    };

    runner = {
      inherit (cfg) capacity labels;

      # Down from the three-hour default, which the upstream security notes
      # single out: with capacity 1, one job that never finishes holds the only
      # slot on this host for three hours, and a `while true` loop is enough to
      # do it by accident. Nothing here legitimately builds for an hour.
      timeout = "1h";

      # How long a shutdown waits for running jobs before cancelling them. Kept
      # equal to `timeout` so a rebuild that restarts this unit does not kill a
      # job that was going to succeed.
      shutdown_timeout = "1h";
    };

    cache = {
      # Serves ACTIONS_CACHE_URL to workflows that use actions/cache or
      # setup-go. The cache is held here, on this host, and never sent to
      # Forgejo.
      #
      # The proxy binds a port on the host and the job container has to reach
      # back to it. Under rootless Podman the container's view of "the host" is
      # a user network namespace rather than the real interface, so if cache
      # steps start failing to connect, `cache.host` is the setting that pins a
      # reachable address instead of letting the runner guess one.
      enabled = true;
    };

    container = {
      # Empty means a fresh network per job, with that job's service and step
      # containers on it and nothing else. "host" or "bridge" would let a
      # workflow reach loopback services on this machine — the reverse proxy is
      # the only thing that is supposed to.
      network = "";

      # The two settings that decide whether a workflow is confined at all:
      # privileged containers are root on this host, and anything listed in
      # valid_volumes may be mounted into a job.
      privileged = false;

      # This is an allowlist for `options` below as much as for what a workflow
      # asks for — the runner checks its own mounts against it too, and silently
      # logs "is not a valid volume, will be ignored" rather than failing to
      # start. An empty list here is what a shared store is worth nothing.
      #
      # Naming the store volume does let a workflow mount it explicitly, which
      # sounds like a widening and is not: `options` already puts it in every
      # job on this host, writable. Nothing else is listed, so a workflow still
      # cannot reach a path on the host.
      valid_volumes = lib.optional (cfg.nixImage != null) nixStoreVolume;

      # No container runtime socket inside job containers. A job can therefore
      # not start containers of its own — `docker build` and dind-style
      # workflows will not work here, deliberately, because handing a job the
      # socket the runner itself uses hands it the runner's privileges.
      #
      # This is separate from how the runner reaches Podman to create the job
      # container in the first place: that comes from DOCKER_HOST in the unit
      # below, which "-" leaves untouched.
      docker_host = "-";

      # Note the scope: the runner has one `options` for all job containers, not
      # one per label, so the shared store is mounted into node-image jobs too —
      # writable, as it has to be. Any job on this host can therefore write into
      # the store that a later job builds against, which is a real weakening of
      # the isolation the rest of this block is buying. It is acceptable here
      # only because registration is closed and every workflow on this forge is
      # already the same person's. It stops being acceptable the moment someone
      # else can push a workflow.
      options = lib.optionalString (cfg.nixImage != null) "--volume=${nixStoreVolume}:/nix";
    };
  };

  baseConfig = settingsFormat.generate "forgejo-runner-base.yaml" (
    lib.recursiveUpdate baseSettings cfg.settings
  );

  # Appended to the generated config at start, once the UUID is known. The
  # connection name is a local label with no meaning to Forgejo; it only has to
  # be unique within this file.
  #
  # The tailnet name, not git.mischief.town, and this is the single setting that
  # decides the network path for everything Actions does here. The runner does
  # not merely poll at this address — it overwrites the job's own environment
  # with it before starting a container: `GITHUB_SERVER_URL`,
  # `ACTIONS_RUNTIME_URL` and `ACTIONS_RESULTS_URL` are all rewritten from the
  # connection address in internal/app/run/runner.go, discarding the `server_url`
  # Forgejo derived from ROOT_URL. So `actions/checkout` clones from here and
  # `actions/upload-artifact` uploads to here.
  #
  # That is the point — none of it crosses Cloudflare, which caps a request body
  # at 100 MB on the free tier — and it is also the one thing to watch on first
  # run. Job containers get their own network namespace (`container.network` is
  # empty, deliberately), so reaching a 100.64/10 address and resolving MagicDNS
  # has to work from inside rootless Podman's network, not just from the host.
  # If checkout fails to resolve this name while the daemon itself connects
  # fine, that gap is the cause.
  connectionTemplate = pkgs.writeText "forgejo-runner-connection.yaml" ''
    server:
      connections:
        mischief-town:
          url: "https://${networkMap.forgejo.tailnetDomain}"
          uuid: "@UUID@"
          token_url: "file:$CREDENTIALS_DIRECTORY/token"
  '';

  writeConfig = pkgs.writeShellScript "forgejo-runner-write-config" ''
    set -euo pipefail
    umask 077

    token="$(tr -d '[:space:]' < "$CREDENTIALS_DIRECTORY/token")"
    if [ "''${#token}" -ne 40 ]; then
      echo "forgejo-runner: the token must be 40 hexadecimal characters, found ''${#token}" >&2
      exit 1
    fi

    # Forgejo identifies this runner by a UUID it derives from the first 16
    # characters of the token, taken as raw bytes rather than decoded hex — see
    # `RegisterRunner` in models/actions/forgejo.go. Recomputing it here is what
    # makes the token the only thing Carbon and this host have to share: there
    # is no registration step whose output has to be captured and fed back.
    hex="$(printf '%s' "''${token:0:16}" | od -An -tx1 -v | tr -d ' \n')"
    uuid="''${hex:0:8}-''${hex:8:4}-''${hex:12:4}-''${hex:16:4}-''${hex:20:12}"

    socket="${socketPath}"
    if [ ! -S "$socket" ]; then
      echo "forgejo-runner: no rootless Podman socket at $socket." >&2
      echo "  It is started by ${user}'s own systemd instance, which only runs" >&2
      echo "  at boot because that user lingers. Check: loginctl user-status ${user}" >&2
      exit 1
    fi

    # The token itself never reaches this file. `token_url` keeps it in the
    # credentials directory, which is a tmpfs only this unit can read, and the
    # runner resolves the $CREDENTIALS_DIRECTORY placeholder itself at load.
    {
      cat ${baseConfig}
      printf '\n'
      sed "s|@UUID@|$uuid|" ${connectionTemplate}
    } > ${configFile}
  '';

  daemonScript = pkgs.writeShellScript "forgejo-runner-daemon" ''
    set -euo pipefail

    # Points the runner's container client at rootless Podman. It has to arrive
    # through the environment rather than through `container.docker_host`,
    # because a socket named there is also bind-mounted into every job
    # container — see the comment on that setting above.
    export DOCKER_HOST="unix://${socketPath}"

    exec ${lib.getExe pkgs.forgejo-runner} daemon --config ${configFile}
  '';
in
{
  options.myNixOS.services.forgejo.runner = {
    enable = lib.mkEnableOption "Forgejo Actions runner";

    name = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = ''
        The name this runner is registered under. It also selects the secret,
        at `secrets/forgejo/runner-<name>.age`, and has to match a key of
        `myNixOS.services.forgejo.runners` on the host running the forge.
      '';
    };

    labels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "docker:docker://data.forgejo.org/oci/node:lts"
        "ubuntu-latest:docker://data.forgejo.org/oci/node:lts"
      ]
      ++ lib.optional (cfg.nixImage != null) "nix:docker://${cfg.nixImage}";
      example = lib.literalExpression ''
        [ "docker:docker://data.forgejo.org/oci/node:lts" ]
      '';
      description = ''
        `<name>:<type>://<image>` entries deciding which jobs this runner will
        accept and what it runs them in. A workflow's `runs-on` is matched
        against the names.

        Only `docker` labels are used here. A `host` label would run the job's
        steps as this unit's own user with no container between them and the
        machine, which also puts the runner's token within reach of the job.

        `ubuntu-latest` is an alias rather than an Ubuntu image: workflows
        written against GitHub reach for that name, and Forgejo's node image
        carries enough of what they assume to be worth answering to it.

        `nix` comes from `nixImage` and is the odd one out: it carries Nix and
        git but no node, so no `uses:` step can run under it — the runner
        executes JavaScript actions with the image's own node, and there isn't
        one. Workflows on this label do their own checkout with git. That is the
        trade for a job that starts with a working Nix rather than installing
        one.

        Note that images are pulled once and then reused forever — the runner
        does the equivalent of `docker run`, not `docker pull`. A floating tag
        like `:lts` goes stale silently; `container.force_pull` through
        `settings` is the trade if that matters more than the bandwidth.
      '';
    };

    nixImage = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "docker.io/nixos/nix:2.35.1";
      example = null;
      description = ''
        Image behind the `nix` label, and the thing the persistent store volume
        is keyed on. `null` drops both — no `nix` label is offered and no volume
        is mounted.

        Fully qualified on purpose: Podman resolves short names against
        `unqualified-search-registries`, and this reference is passed through to
        it verbatim.

        Pinned rather than floating because the runner pulls an image once and
        then reuses it. A floating tag here would be worse than elsewhere: the
        store volume is keyed on this string, so a tag that moves underneath the
        same name would keep the volume — and the Nix inside it — frozen while
        appearing to have been updated.
      '';
    };

    storeVolume = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      readOnly = true;
      default = if cfg.nixImage == null then null else nixStoreVolume;
      defaultText = lib.literalMD "derived from `nixImage`";
      description = ''
        The Podman volume holding the shared `/nix`. Derived, not settable —
        it exists so that tooling outside the closure can ask the flake for the
        name instead of recomputing it. `just runner-gc` is the caller.
      '';
    };

    capacity = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = ''
        How many jobs this runner executes at once. Each one is unconstrained in
        CPU, memory and I/O unless `container.options` is set through
        `settings`, so raising this raises how much of the host a single
        workflow can take. Three concurrent Nix builds on a four-core NUC is
        already oversubscribed; `--cpus` and `--memory` there are the answer if
        it starts hurting the host's other services.

        Above 1 this carries a constraint that is not visible from here: no job
        may run a garbage collection against the shared store — see the comment
        on `nixStoreVolume`.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule { freeformType = settingsFormat.type; };
      default = { };
      example = lib.literalExpression ''
        { container.options = "--memory=4g --cpus=2"; }
      '';
      description = ''
        Merged over the module's own runner configuration. The place for
        per-host tuning — resource limits in particular, which the runner
        applies to job containers only through `container.options`.

        `server` is rejected: the connection block is generated at start,
        because it carries a UUID that is only knowable once the token has been
        read.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(cfg.settings ? server);
        message = "myNixOS.services.forgejo.runner.settings may not set `server`; the connection is generated at startup from the token.";
      }
      {
        # The forge is reached at a `.ts.net` name that exists only on the
        # tailnet, so without this the runner has nothing to resolve and the
        # failure arrives as a DNS error in a unit log rather than here.
        assertion = config.services.tailscale.enable;
        message = "myNixOS.services.forgejo.runner reaches Forgejo over the tailnet, but services.tailscale.enable is false.";
      }
    ];

    age.secrets.forgejoRunnerToken.file = "${self}/secrets/forgejo/runner-${cfg.name}.age";

    # Rootless. A job that breaks out of its container lands as an unprivileged
    # user in a user namespace, not as root on the host — which is the whole
    # reason for the linger/subuid apparatus below, since the alternative
    # (membership in `podman` or `docker`) is root-equivalent by construction.
    virtualisation.podman.enable = true;

    users.groups.${user} = { };
    users.users.${user} = {
      isSystemUser = true;
      group = user;

      home = stateDir;
      createHome = true;

      # Container image layers are mapped onto these ranges. Without them
      # rootless Podman has no ids to map into and refuses to start a container.
      # System users do not get a range by default.
      autoSubUidGidRange = true;

      # Nothing logs in as this user, so without lingering its systemd instance
      # never starts and podman.socket with it — the runner would come up and
      # find nothing to talk to on every boot.
      linger = true;

      shell = "${pkgs.shadow}/bin/nologin";
    };

    systemd.services.forgejo-runner = {
      description = "Forgejo Actions runner";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      path = [
        pkgs.coreutils
        pkgs.gnused
      ];

      environment = {
        HOME = stateDir;
      };

      serviceConfig = {
        User = user;
        Group = user;
        WorkingDirectory = stateDir;

        RuntimeDirectory = user;
        RuntimeDirectoryMode = "0700";

        # Read by systemd as root and dropped into a per-unit tmpfs, so the
        # agenix file stays root-owned and the runner reads it without the
        # secret ever having a path on disk that another service could open.
        LoadCredential = [ "token:${config.age.secrets.forgejoRunnerToken.path}" ];

        ExecStartPre = writeConfig;
        ExecStart = daemonScript;

        # Covers the ordinary startup race as well as failure: this unit and the
        # runner user's own systemd instance are not ordered against each other
        # — a system unit cannot sensibly wait on a user manager — so on a cold
        # boot the first attempt may well find no Podman socket and exit.
        # Retrying is the ordering.
        Restart = "on-failure";
        RestartSec = 10;

        # Deliberately unhardened beyond this. NoNewPrivileges would block the
        # setuid newuidmap/newgidmap helpers that rootless Podman needs to set
        # up its user namespace, and the namespace restrictions that would be
        # worth having here are the ones Podman is itself using. The isolation
        # that matters is the container around the job, not the sandbox around
        # the daemon that starts it.
      };
    };
  };
}
