{
  config,
  lib,
  ...
}:
let
  cfg = config.myNixOS.services.fail2ban;
in
{
  options.myNixOS.services.fail2ban = {
    enable = lib.mkEnableOption "fail2ban intrusion prevention";

    enableCaddyJail = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable fail2ban jail for Caddy 401/403 responses.";
    };

    enableForgejoJail = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable fail2ban jail for Forgejo SSH authentication failures.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.fail2ban = {
      enable = true;
      maxretry = 5;
      bantime = "1h";

      bantime-increment = {
        enable = true;
        multipliers = "2 4 8 16 32 64";
        maxtime = "168h";
        overalljails = true;
      };

      ignoreIP = [
        "127.0.0.1/8"
        "::1"
        # tailscale CGNAT range — never ban tailnet peers
        "100.64.0.0/10"
      ];

      jails.sshd.settings = {
        enabled = true;
        port = "ssh";
        filter = "sshd";
        maxretry = 3;
        bantime = "1h";
      };
    };

    services.fail2ban.jails.caddy-auth = lib.mkIf cfg.enableCaddyJail {
      settings = {
        enabled = true;
        backend = "systemd";
        journalmatch = "_SYSTEMD_UNIT=caddy.service";
        maxretry = 10;
        findtime = "10m";
        bantime = "1h";
        filter = "caddy-auth";
      };
    };

    environment.etc."fail2ban/filter.d/caddy-auth.conf" = lib.mkIf cfg.enableCaddyJail {
      text = ''
        [Definition]
        failregex = .*"remote_ip":"<HOST>".*"status":40[13]
        ignoreregex =
      '';
    };

    services.fail2ban.jails.forgejo-ssh = lib.mkIf cfg.enableForgejoJail {
      settings = {
        enabled = true;
        backend = "systemd";
        journalmatch = "_SYSTEMD_UNIT=forgejo.service";
        port = "2222";
        maxretry = 5;
        findtime = "10m";
        bantime = "1h";
        filter = "forgejo-ssh";
      };
    };

    environment.etc."fail2ban/filter.d/forgejo-ssh.conf" = lib.mkIf cfg.enableForgejoJail {
      text = ''
        [Definition]
        failregex = Failed connection from <HOST>:\d+ with error:.*
        ignoreregex =
      '';
    };
  };
}
