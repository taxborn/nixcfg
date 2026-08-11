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

  # A vhost name is not always a usable filename, so the upstream Caddy module
  # rewrites it before building the default `access-<host>.log` path. The
  # pre-creation rule below has to land on exactly the same name or it creates
  # one file while Caddy writes another, which reads as working — the file is
  # there, the jail's glob matches it — while the log it was meant to cover
  # stays unwatched.
  #
  # `/` and space are what upstream replaces. `*` is ours: a wildcard vhost like
  # `*.taxborn.com` otherwise puts a literal glob character in a filename, in a
  # directory the caddy-auth jail reads by glob. Legal, and a trap to leave for
  # whoever next runs a shell in /var/log/caddy.
  caddyLogName = host: lib.replaceStrings [ "/" " " "*" ] [ "_" "_" "wildcard" ] host;

  # The apps behind Caddy do not answer a failed login with a status code the
  # proxy can see — Vaultwarden's token endpoint returns 400 (OAuth2
  # `invalid_grant`) and Forgejo re-renders its login page with 200 — so the
  # caddy-auth jail is structurally blind to credential stuffing against them.
  # Both do log the attempt, with the real client address, to their own unit's
  # journal. Watch that instead.
  #
  # Gate on the service actually running on this host: a jail whose unit does
  # not exist matches nothing, forever, and silently — which is exactly the
  # failure mode that kept caddy-auth inert for weeks.
  vaultwardenJail = config.services.vaultwarden.enable;
  forgejoJail = config.services.forgejo.enable;
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
      #
      # This sits in the generated [DEFAULT] section, so every jail below
      # inherits it; there is no per-jail opt-in to forget. Two things have to
      # hold for it to actually protect a jail, and both are worth preserving
      # when adding one: the filter has to extract the tailnet address rather
      # than a proxy's (see the X-Real-IP notes on the app jails), and it has
      # to extract it as a literal address — hence <ADDR> everywhere below
      # rather than <HOST>, which also accepts names and would put a DNS
      # lookup between a log line and a ban decision.
      #
      # Not covered, deliberately: a public address is bannable, including
      # yours. That is the point of the jails. It costs no access, because
      # tailnet SSH is on a different address that this list exempts.
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

        # Caddy stamps each JSON line with a float epoch in `ts`, and none of
        # fail2ban's built-in templates match it — `fail2ban-regex` reports no
        # date-template hits at all, so every line falls back to the time
        # fail2ban happened to read it. Live tailing hides that, but the jail
        # resumes from a saved file position on restart, and undated backlog
        # replayed as "now" can trip `maxretry` against `findtime` in one go
        # and ban whoever is in the log. The braced form is required: a bare
        # EPOCH is only recognised anchored at line start, which this is not.
        datepattern = ''"ts":{EPOCH}'';
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
        "f ${config.services.caddy.logDir}/access-${caddyLogName host}.log 0640 ${config.services.caddy.user} ${config.services.caddy.group} -"
      ) caddyVirtualHosts
    );

    # `client_ip`, not `remote_ip`: behind Cloudflare's proxy the peer address
    # is a Cloudflare edge, so matching on remote_ip would ban Cloudflare and
    # take every site down for everyone. Caddy resolves client_ip from
    # CF-Connecting-IP for the trusted ranges configured in the caddy module,
    # and emits it for every request — on a direct or tailnet connection it is
    # simply equal to remote_ip, so this is correct either way.
    # 403 only, deliberately not 401. Across ~40k logged requests the sole 40x
    # this jail ever saw was a Bitwarden iOS client getting a 401 from
    # /api/accounts/revision-date on an expired token — a real user, not an
    # attacker. Vaultwarden hands out 401 as ordinary token-refresh signalling
    # and mobile clients retry it in bursts, so matching 401 aimed a
    # ten-strikes-in-ten-minutes ban squarely at the people who own the data.
    # 403 is the one of the pair that means "asked for something not allowed".
    environment.etc."fail2ban/filter.d/caddy-auth.conf" = lib.mkIf caddyJail {
      text = ''
        [Definition]
        failregex = .*"client_ip":"<ADDR>".*"status":403
        ignoreregex =
      '';
    };

    # Both jails read the journal, so fail2ban takes the event time from the
    # journal entry and no datepattern is needed the way caddy-auth needs one.
    services.fail2ban.jails.vaultwarden = lib.mkIf vaultwardenJail {
      settings = {
        enabled = true;
        backend = "systemd";
        journalmatch = "_SYSTEMD_UNIT=vaultwarden.service";
        filter = "vaultwarden";
        maxretry = 5;
        findtime = "10m";
        bantime = "1h";
      };
    };

    services.fail2ban.jails.forgejo = lib.mkIf forgejoJail {
      settings = {
        enabled = true;
        backend = "systemd";
        journalmatch = "_SYSTEMD_UNIT=forgejo.service";
        filter = "forgejo";
        maxretry = 5;
        findtime = "10m";
        bantime = "1h";
      };
    };

    # Matches only a wrong password. Vaultwarden logs `Invalid refresh token`,
    # `Token has expired` and `Error decoding JWT` at the same ERROR level and
    # with an IP attached, but those are what a logged-in client produces when
    # its token ages out — banning on them repeats the 401 mistake above.
    #
    # The address is unbracketed here even when it is IPv6, so <ADDR> (a
    # literal address) is right rather than <HOST> (address or hostname).
    # Vaultwarden sees the true client because the Caddy vhost forwards
    # X-Real-IP from {client_ip}; without that this would ban a Cloudflare edge.
    environment.etc."fail2ban/filter.d/vaultwarden.conf" = lib.mkIf vaultwardenJail {
      text = ''
        [Definition]
        failregex = ^.*Username or password is incorrect\. Try again\. IP: <ADDR>\.
        ignoreregex =
      '';
    };

    # Covers both a bad password and an unknown account, which Forgejo reports
    # on the same line prefix and differs only after the colon — an attacker
    # guessing usernames should burn retries just as fast as one guessing
    # passwords. Forgejo renders the peer as a Go net.Addr, so IPv6 arrives
    # bracketed (`from [2001:db8::1]:41234`) and IPv4 bare; <ADDR> parses both
    # and yields the address without the port.
    environment.etc."fail2ban/filter.d/forgejo.conf" = lib.mkIf forgejoJail {
      text = ''
        [Definition]
        failregex = ^.*Failed authentication attempt for .+ from <ADDR>
        ignoreregex =
      '';
    };
  };
}
