{
  config,
  lib,
  ...
}:
let
  cfg = config.myNixOS.services.fail2ban;

  # Every vhost gets its own access log, and the jail reads them by glob.
  # fail2ban resolves that glob at startup and treats "no files" as a fatal
  # configuration error — `Have not found any log file for caddy-auth jail` —
  # so on a host that runs Caddy without serving anything, asking for the jail
  # takes fail2ban down with it. The server profile enables Caddy everywhere,
  # including hosts that proxy nothing, so gate on there being something to
  # watch rather than on the intent to watch it.
  caddyVirtualHosts = config.services.caddy.virtualHosts;
  caddyJail = cfg.enableCaddyJail && caddyVirtualHosts != { };
in
{
  options.myNixOS.services.fail2ban = {
    enable = lib.mkEnableOption "fail2ban intrusion prevention";

    enableCaddyJail = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable the fail2ban jail for Caddy 401/403 responses.

        Has no effect on a host with no `services.caddy.virtualHosts`: the jail
        would have no log file to open and fail2ban exits rather than start
        without it.
      '';
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

      # Never ban tailnet peers. Tailscale gives each node both a CGNAT v4
      # address and a ULA v6 address, and a peer may arrive over either, so
      # both ranges have to be listed — a v4-only entry would leave every
      # tailnet connection that happened to pick v6 bannable.
      ignoreIP = [
        "100.64.0.0/10"
        "fd7a:115c:a1e0::/48"
      ];

      # The module auto-creates the sshd jail (enabled, correct port/filter);
      # only tighten its retry budget below the global maxretry.
      jails.sshd.settings.maxretry = 3;
    };

    # Caddy writes one access log *file* per vhost and sends only its own
    # runtime log to the journal, so the systemd backend this jail used to
    # carry matched nothing at all — the jail was inert from the day it was
    # switched on. Read the files instead.
    services.fail2ban.jails.caddy-auth = lib.mkIf caddyJail {
      settings = {
        enabled = true;
        backend = "auto";
        logpath = "${config.services.caddy.logDir}/access-*.log";
        maxretry = 10;
        findtime = "10m";
        bantime = "1h";
        filter = "caddy-auth";
      };
    };

    # fail2ban expands that glob once, when the jail starts, and Caddy creates
    # each access log lazily on the vhost's first request. Without this, a
    # newly deployed vhost stays unwatched until something happens to restart
    # fail2ban, which could be weeks. Pre-creating the files means a vhost is
    # covered from its first request instead.
    systemd.tmpfiles.rules = lib.mkIf caddyJail (
      lib.mapAttrsToList (
        host: _:
        "f ${config.services.caddy.logDir}/access-${host}.log 0640 ${config.services.caddy.user} ${config.services.caddy.group} -"
      ) caddyVirtualHosts
    );

    # `client_ip`, not `remote_ip`: behind Cloudflare's proxy the peer address
    # is a Cloudflare edge, so matching on remote_ip would ban Cloudflare and
    # take every site down for everyone. Caddy resolves client_ip from
    # CF-Connecting-IP for the trusted ranges configured in the caddy module,
    # and emits it for every request — on a direct or tailnet connection it is
    # simply equal to remote_ip, so this is correct either way.
    environment.etc."fail2ban/filter.d/caddy-auth.conf" = lib.mkIf caddyJail {
      text = ''
        [Definition]
        failregex = .*"client_ip":"<HOST>".*"status":40[13]
        ignoreregex =
      '';
    };
  };
}
