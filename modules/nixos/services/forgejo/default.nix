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
    catppuccin.forgejo.enable = true;

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

      database.type = "sqlite3";
      lfs.enable = true;
      secrets.mailer.PASSWD = config.age.secrets.forgejoMail.path;

      settings = {
        DEFAULT.APP_NAME = appName;
        database.SQLITE_JOURNAL_MODE = "WAL";
        server = {
          DOMAIN = networkMap.forgejo.domain;
          ROOT_URL = "https://${networkMap.forgejo.domain}";
          HTTP_ADDR = "127.0.0.1";
          HTTP_PORT = networkMap.forgejo.port;
          LANDING_PAGE = "explore";

          START_SSH_SERVER = true;
          SSH_LISTEN_PORT = networkMap.forgejo.sshPort;
          SSH_PORT = networkMap.forgejo.sshPort;
          SSH_DOMAIN = networkMap.forgejo.sshDomain;
          BUILTIN_SSH_SERVER_USER = "git";
          SSH_CREATE_AUTHORIZED_KEYS_FILE = false;
        };

        actions = {
          ENABLED = true;
          DEFAULT_ACTIONS_URL = "https://data.forgejo.org";
          ARTIFACT_RETENTION_DAYS = 30;
        };

        cron = {
          ENABLED = true;
          RUN_AT_START = true;
        };

        federation.ENABLED = false;
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

    environment.systemPackages = [
      config.services.forgejo.package
      pkgs.sqlite
    ];

    users.groups.${user} = { };
    users.users.${user} = {
      isSystemUser = true;
      group = user;
      home = stateDir;
      shell = "${pkgs.shadow}/bin/nologin";
    };
  };
}
