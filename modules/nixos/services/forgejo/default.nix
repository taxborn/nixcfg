{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  networkMap = config.mySnippets.mischief-town.networkMap;

  appName = "Mischief's Forge";
  mailerUser = "forgejo@mischief.town";

  stateDir = "/var/lib/forgejo";
  signingKeyDir = "${stateDir}/signing";

  # Forgejo runs under this name rather than the module's `forgejo` default so
  # clone URLs read `git@host:owner/repo.git`, which is what every tool and
  # every set of fingers expects. Nothing ever authenticates as it — the
  # builtin SSH server answers git traffic itself — so it gets no shell, for
  # the reason spelled out at the bottom of this file.
  user = "git";
in
{
  options.myNixOS.services.forgejo.enable = lib.mkEnableOption "Forgejo git forge";

  config = lib.mkIf config.myNixOS.services.forgejo.enable {
    age.secrets = {
      forgejoMail.file = "${self}/secrets/forgejo/mail.age";

      forgejoSigningKey = {
        file = "${self}/secrets/forgejo/signing-key.age";
        path = "${signingKeyDir}/key";
        owner = user;
        group = user;
        mode = "0400";
      };
    };

    # Forgejo signs with `ssh-keygen -Y sign`, which wants the private key
    # beside its public half under the same basename. The private half is the
    # agenix secret above; the public half is not secret and lives in the repo.
    systemd.tmpfiles.rules = [
      "d ${signingKeyDir} 0750 ${user} ${user} -"
      "L+ ${signingKeyDir}/key.pub - - - - ${self}/secrets/forgejo/signing-key.pub"
    ];

    services.forgejo = {
      enable = true;
      # The module defaults to the LTS series; track the current one.
      package = pkgs.forgejo;

      inherit user;
      group = user;

      database = {
        # One user, one forge. SQLite carries that without a second daemon to
        # run, patch, and version-pin, and without a `pg_upgrade` day whenever
        # nixpkgs moves its default major. The whole database is one file under
        # the state directory — `path` is left at the module's default,
        # /var/lib/forgejo/data/forgejo.db, which is the path carbon hands to
        # its backup hook.
        #
        # There is no database password here for the same reason there was none
        # under postgres: nothing is listening. Access is filesystem
        # permissions on a file only this service's user can open.
        type = "sqlite3";
      };

      lfs.enable = true;

      secrets.mailer.PASSWD = config.age.secrets.forgejoMail.path;

      settings = {
        DEFAULT.APP_NAME = appName;

        # Readers do not block writers under WAL, which is what makes the
        # nightly backup invisible to the running service. The dump hook is a
        # `sqlite3 .dump` — one long read over the whole database — and under
        # the default rollback journal it holds a shared lock for the length of
        # that read, so anything Forgejo tried to write meanwhile (a push, or
        # one of the crons below) would fail with "database is locked" as soon
        # as SQLITE_TIMEOUT ran out half a second later.
        database.SQLITE_JOURNAL_MODE = "WAL";

        server = {
          DOMAIN = networkMap.forgejo.domain;
          ROOT_URL = "https://${networkMap.forgejo.domain}";

          # Caddy is the only thing that should reach this. The module defaults
          # HTTP_ADDR to 0.0.0.0, which would put Forgejo on carbon's public
          # address behind nothing but the firewall.
          HTTP_ADDR = "127.0.0.1";
          HTTP_PORT = networkMap.forgejo.port;

          LANDING_PAGE = "explore";

          # Git over SSH runs on Forgejo's own SSH server, on its own port,
          # deliberately *not* on the host's sshd at port 22.
          #
          # Serving it from sshd is what the obvious reading of this setup
          # suggests, and it does not work here: Tailscale SSH (`--ssh`, in the
          # tailscale module) takes over port 22 on the tailnet interface and
          # authenticates by tailnet identity. It never reads authorized_keys,
          # so Forgejo's forced `forgejo serv` command is skipped entirely and
          # the client's own command runs against the user's shell — a clone
          # fails with git-upload-pack's "does not appear to be a git
          # repository", and any tailnet peer the SSH ACL admits gets arbitrary
          # execution as this user. Confining git to the tailnet and then
          # serving it from sshd are mutually exclusive on this host.
          #
          # The builtin server has no such conflict: it holds a port Tailscale
          # does not touch, keeps key handling inside Forgejo, and needs no
          # login user at all.
          START_SSH_SERVER = true;
          SSH_LISTEN_PORT = networkMap.forgejo.sshPort;
          SSH_PORT = networkMap.forgejo.sshPort;
          SSH_DOMAIN = networkMap.forgejo.sshDomain;

          # Names the user half of clone URLs. With the builtin server this is
          # a label Forgejo answers to, not a local account.
          BUILTIN_SSH_SERVER_USER = "git";

          # Nothing should be maintaining an authorized_keys file: the builtin
          # server holds the keys itself, and a stale file would be a second,
          # unmanaged way into the account.
          SSH_CREATE_AUTHORIZED_KEYS_FILE = false;
        };

        actions = {
          # On by default since 1.21, pinned because it is load-bearing now
          # rather than incidental: `runners` in actions.nix registers runners
          # against this instance and they have nothing to poll without it.
          ENABLED = true;

          # Where a bare `uses:` resolves. `uses: actions/checkout@v6` becomes
          # https://data.forgejo.org/actions/checkout — Forgejo's own mirror of
          # actions known to work here and published under a free licence.
          #
          # This is the stock value, and it is worth stating rather than
          # inheriting, because the failure mode of pointing it somewhere with
          # open registration is quiet: `uses: foo/bar@main` would run whatever
          # is at that path, and a stranger who can create `foo/bar` there
          # chooses what our workflows execute.
          DEFAULT_ACTIONS_URL = "https://data.forgejo.org";

          # Down from 90. Artifacts land in
          # /var/lib/forgejo/data/actions_artifacts, which is the one piece of
          # Actions state large enough to matter to Carbon's disk — and it is
          # excluded from the borg set (see hosts/carbon) because a build
          # artifact is reproducible by re-running the job that made it. Thirty
          # days is long enough to fetch something from a run you have half
          # forgotten and short enough that a runaway workflow cannot quietly
          # fill the disk over a quarter.
          #
          # LOG_RETENTION_DAYS is left at its 365-day default: job logs are
          # zstd-compressed text, they are the record of *why* a run failed,
          # and they cost almost nothing to keep.
          ARTIFACT_RETENTION_DAYS = 30;
        };

        cron = {
          ENABLED = true;
          RUN_AT_START = true;
        };

        # Still early, and not useful enough yet to be worth the surface it
        # adds to a forge that only needs to serve one person.
        federation.ENABLED = false;

        # Roughly doubles the on-disk footprint of repository content. Carbon
        # has the room, and the indexes are excluded from backups because
        # Forgejo rebuilds them on demand.
        indexer.REPO_INDEXER_ENABLED = true;

        picture = {
          AVATAR_MAX_FILE_SIZE = 5242880;
          ENABLE_FEDERATED_AVATAR = true;
        };

        repository = {
          ENABLE_PUSH_CREATE_ORG = true;
          ENABLE_PUSH_CREATE_USER = true;
        };

        "repository.signing" = {
          FORMAT = "ssh";
          SIGNING_KEY = "${signingKeyDir}/key.pub";
          SIGNING_NAME = appName;
          SIGNING_EMAIL = mailerUser;
          INITIAL_COMMIT = "always";
          CRUD_ACTIONS = "always";
          WIKI = "always";
          MERGES = "always";
        };

        mailer = {
          ENABLED = true;
          PROTOCOL = "smtps";
          SMTP_ADDR = "smtp.fastmail.com";
          SMTP_PORT = 465;
          USER = "hello@taxborn.com";
          FROM = "\"${appName}\" <${mailerUser}>";
        };

        service = {
          # Closed, because Actions runners exist now. An open signup form on
          # an instance with runners is an unauthenticated path to code
          # execution on Argon and Helium: `ENABLE_PUSH_CREATE_USER` above lets
          # any account create a repository by pushing to it, and a repository
          # is all a workflow needs. Nothing about the runner configuration can
          # close that hole from its own side — the account is legitimate and
          # the workflow is in a repository its owner controls.
          #
          # This replaces `ALLOW_ONLY_INTERNAL_REGISTRATION = true`, which was
          # never the guard it reads like: it forces signups through Forgejo's
          # own form rather than a third-party OAuth provider, and does nothing
          # to stop the signup itself. With registration off it has no effect
          # at all, so it is gone rather than left as reassuring noise.
          #
          # Accounts are made with `forgejo admin user create` instead. See the
          # README for how to run that against this instance's config.
          DISABLE_REGISTRATION = true;
          ENABLE_NOTIFY_MAIL = true;
        };

        security.PASSWORD_CHECK_PWN = true;
        session.COOKIE_SECURE = true;

        "ui.meta" = {
          AUTHOR = "Braxton Fair";
          DESCRIPTION = "Self-hosted git forge for projects + toys.";
          KEYWORDS = "git,source code,forge,forĝejo,braxton fair,mischief town";
        };
      };
    };

    # `forgejo admin …` is the only way to make the first account, since
    # registration is disabled, and the nixpkgs module puts the binary nowhere
    # a person can reach — it exists only inside the unit's PATH. `sqlite3` is
    # here for the same reason: the database is a file now, and looking at it
    # is a thing that will be wanted on a day when the web UI is the problem.
    #
    # Both need `--config`/the file path spelled out when run by hand; the
    # binary's own default work path is its store directory. See the README.
    environment.systemPackages = [
      config.services.forgejo.package
      pkgs.sqlite
    ];

    # The forgejo module only declares these when the service runs under its
    # default name.
    #
    # No login shell, deliberately. Nothing needs to authenticate as this user
    # — the builtin SSH server answers git traffic itself — and leaving it a
    # shell would hand a shell here to every tailnet peer the Tailscale SSH ACL
    # admits, since Tailscale SSH decides who may log in as what without
    # reference to sshd's rules.
    users.groups.${user} = { };
    users.users.${user} = {
      isSystemUser = true;
      group = user;
      home = stateDir;
      shell = "${pkgs.shadow}/bin/nologin";
    };

    # The listen port is deliberately absent from `allowedTCPPorts`, and with
    # `HTTP_ADDR` on loopback that is belt and braces rather than the boundary:
    # there is no socket on a real interface for the firewall to have an opinion
    # about. Caddy is the only local client.
    #
    # Tailnet peers — the Actions runners on Argon and Helium — reach the forge
    # through a second Caddy vhost bound to a userspace Tailscale node, in
    # hosts/carbon/proxy.nix. That is what `networkMap.forgejo.tailnetDomain`
    # names. Two alternatives were available and are worse:
    #
    #   - Dropping HTTP_ADDR so Forgejo binds 0.0.0.0 and letting the firewall
    #     confine it. The tailscale interface is in `trustedInterfaces`, so this
    #     does work, and it leaves the forge listening on Carbon's public
    #     address with nothing but a firewall rule in front of it.
    #   - Binding HTTP_ADDR to the tailnet address. Forgejo then fails to start
    #     whenever tailscaled has not yet assigned it, and Caddy's public vhost
    #     has to proxy to a tailnet address to reach a service on its own host.

  };
}
