{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  networkMap = config.mySnippets.mischief-town.networkMap;
  signingKeyDir = "/var/lib/forgejo/signing";

  appName = "Mischief's Forge";
  mailerUser = "forgejo@mischief.town";
in
{
  options.myNixOS.services.forgejo.enable = lib.mkEnableOption "Forgejo web server.";

  config = lib.mkIf config.myNixOS.services.forgejo.enable {
    age.secrets = {
      mail-forgejo.file = "${self.inputs.secrets}/forgejo/mail.age";
      postgres-forgejo.file = "${self.inputs.secrets}/forgejo/postgres.age";
      forgejo-signing-key = {
        file = "${self.inputs.secrets}/forgejo/forgejo-key.age";
        path = "${signingKeyDir}/key";
        owner = "forgejo";
        group = "forgejo";
        mode = "0400";
      };
    };

    systemd.tmpfiles.rules = [
      "d ${signingKeyDir} 0755 forgejo forgejo -"
      "L+ ${signingKeyDir}/key.pub - - - - ${self.inputs.secrets}/forgejo/forgejo-key.pub"
    ];

    services = {
      postgresql = {
        enable = true;
        package = pkgs.postgresql_18;
        ensureDatabases = [ "forgejo" ];
        ensureUsers = [
          {
            name = "forgejo";
            ensureDBOwnership = true;
          }
        ];
      };

      forgejo = {
        enable = true;
        database = {
          createDatabase = true;
          host = "127.0.0.1";
          name = "forgejo";
          passwordFile = config.age.secrets.postgres-forgejo.path;
          type = "postgres";
          user = "forgejo";
        };

        lfs.enable = true;
        package = pkgs.forgejo; # otherwise it uses lts
        secrets.mailer.PASSWD = config.age.secrets.mail-forgejo.path;

        settings = {
          server = {
            DOMAIN = networkMap.forgejo.domain;
            HTTP_PORT = networkMap.forgejo.port;
            ROOT_URL = "https://${networkMap.forgejo.domain}";

            LANDING_PAGE = "explore";

            SSH_PORT = 2222;
            START_SSH_SERVER = true;
            BUILTIN_SSH_SERVER_USER = "git";
          };
          cron = {
            ENABLED = true;
            RUN_AT_START = true;
          };
          DEFAULT.APP_NAME = appName;
          federation.ENABLED = true;
          indexer.REPO_INDEXER_ENABLED = true; # uses 6x disk space
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
            PROTOCOL = "smtp";
            SMTP_ADDR = "smtp.fastmail.com";
            SMTP_PORT = 465;
            USER = mailerUser;
            FROM = "\"${appName}\" <${mailerUser}>";
          };
          service = {
            ALLOW_ONLY_INTERNAL_REGISTRATION = true;
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
    };

    networking.firewall.allowedTCPPorts = [ 2222 ];

    users.groups.git = { };
    users.users.git = {
      isSystemUser = true;
      createHome = true;
      group = "git";
    };
  };
}
