{
  self,
  lib,
  config,
  pkgs,
  ...
}:
let
  sshPort = 2222;
  sshUser = "git";
in
{
  options.myNixOS.services.forgejo.enable = lib.mkEnableOption "forgejo git forge";

  config = lib.mkIf config.myNixOS.services.forgejo.enable {
    age.secrets = {
      resend.file = "${self.inputs.secrets}/resend.age";
      postgres-forgejo.file = "${self.inputs.secrets}/forgejo/postgres.age";
    };

    services = {
      postgresql = {
        enable = true;
        package = pkgs.postgresql_16;
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
        package = pkgs.forgejo;
        secrets.mailer.PASSWD = config.age.secrets.resend.path;
        settings = {
          actions = {
            ARTIFACT_RETENTION_DAYS = 15;
            ENABLED = true;
            DEFAULT_ACTIONS_URL = "https://github.com";
          };

          cron = {
            ENABLED = true;
            RUN_AT_START = true;
          };

          DEFAULT.APP_NAME = "Mischief's Forge";
          federation.ENABLED = true;
          indexer.REPO_INDEXER_ENABLED = true;

          log = {
            ENABLE_SSH_LOG = true;
            LEVEL = "Debug";
          };

          mailer = {
            ENABLED = true;
            FROM = "Forĝejo <git@git.mischief.town>";
            PROTOCOL = "smtp+starttls";
            SMTP_ADDR = "smtp.resend.com";
            SMTP_PORT = 587;
            USER = "resend";
          };

          picture = {
            AVATAR_MAX_FILE_SIZE = 5242880;
            ENABLE_FEDERATED_AVATAR = true;
          };

          repository = {
            DEFAULT_BRANCH = "main";
            ENABLE_PUSH_CREATE_ORG = true;
            ENABLE_PUSH_CREATE_USER = true;
          };

          security.PASSWORD_CHECK_PWN = true;

          server = {
            DOMAIN = config.mySnippets.mischief-town.networkMap.forgejo.vHost;
            HTTP_PORT = config.mySnippets.mischief-town.networkMap.forgejo.port;
            LANDING_PAGE = "explore";
            LFS_START_SERVER = true;
            ROOT_URL = "https://${config.mySnippets.mischief-town.networkMap.forgejo.vHost}";
            SSH_DOMAIN = config.mySnippets.mischief-town.networkMap.forgejo.vHost;
            SSH_LISTEN_PORT = sshPort;
            SSH_PORT = sshPort;
            SSH_USER = sshUser;
            START_SSH_SERVER = true;
            BUILTIN_SSH_SERVER_USER = sshUser;
          };

          service = {
            ALLOW_ONLY_INTERNAL_REGISTRATION = true;
            DISABLE_REGISTRATION = true;
            ENABLE_NOTIFY_MAIL = true;
          };

          session.COOKIE_SECURE = true;

          "ui.meta" = {
            AUTHOR = "Braxton Fair";
            DESCRIPTION = "Self-hosted git forge for projects + toys.";
            KEYWORDS = "git,source code,forge,forĝejo,braxton fair,mischief town";
          };
        };
      };
    };

    users.groups.git = { };
    users.users.git = {
      isSystemUser = true;
      createHome = true;
      group = "git";
    };

    networking.firewall.allowedTCPPorts = [ sshPort ];
  };
}
