{ config, pkgs, ... }:
let
  domain = "git.mischief.town";
  sshPort = 2222;
  sshUser = "git";
  cfg = config.services.forgejo;
in
{
  services.forgejo = {
    enable = true;
    package = pkgs.forgejo;
    database.type = "postgres";
    lfs.enable = true;
    settings = {
      server = {
        DOMAIN = domain;
        ROOT_URL = "https://${domain}";
        SSH_DOMAIN = domain;
        SSH_PORT = sshPort;
        SSH_USER = sshUser;
        SSH_LISTEN_PORT = sshPort;
        START_SSH_SERVER = true;
        BUILTIN_SSH_SERVER_USER = sshUser;
        HTTP_PORT = 8193;
      };
      actions = {
        ENABLED = true;
      };
    };
  };

  users.groups.git = { };
  users.users.git = {
    isSystemUser = true;
    createHome = false;
    group = "git";
  };

  networking.firewall.allowedTCPPorts = [ sshPort ];

  services.caddy = {
    virtualHosts.${domain}.extraConfig = ''
      reverse_proxy localhost:${toString cfg.settings.server.HTTP_PORT}
    '';
  };
}
