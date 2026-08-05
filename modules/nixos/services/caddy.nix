{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  # Cloudflare's proxy egress ranges. Every public request reaches us from one
  # of these, so they are the set Caddy may believe a forwarded-client header
  # from. Refresh with:
  #   curl -s https://www.cloudflare.com/ips-v4 https://www.cloudflare.com/ips-v6
  # Cloudflare changes these rarely, and a stale entry fails closed: the worst
  # case is that Caddy stops trusting a new edge range and falls back to
  # logging that edge's own address, which is what it did before this existed.
  cloudflareRanges = [
    "173.245.48.0/20"
    "103.21.244.0/22"
    "103.22.200.0/22"
    "103.31.4.0/22"
    "141.101.64.0/18"
    "108.162.192.0/18"
    "190.93.240.0/20"
    "188.114.96.0/20"
    "197.234.240.0/22"
    "198.41.128.0/17"
    "162.158.0.0/15"
    "104.16.0.0/13"
    "104.24.0.0/14"
    "172.64.0.0/13"
    "131.0.72.0/22"
    "2400:cb00::/32"
    "2606:4700::/32"
    "2803:f800::/32"
    "2405:b500::/32"
    "2405:8100::/32"
    "2a06:98c0::/29"
    "2c0f:f248::/32"
  ];

  cfg = config.myNixOS.services.caddy;

  # Per-node blocks for the tailscale plugin, nested inside its global options
  # block below. The plugin only reads node configuration from there, so a
  # tailnet-bound vhost cannot carry its own — hence the option.
  tailscaleNodes = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: conf: ''
      ${name} {
        ${conf}
      }
    '') cfg.tailscaleNodes
  );
in
{
  options.myNixOS.services.caddy = {
    enable = lib.mkEnableOption "Caddy web server.";

    tailscaleNodes = lib.mkOption {
      type = lib.types.attrsOf lib.types.lines;
      default = { };
      example = lib.literalExpression ''
        { paperless = "ephemeral false"; }
      '';
      description = ''
        Node name -> raw Caddyfile directives for the caddy-tailscale plugin.

        A vhost reaches one of these with `bind tailscale/<name>`, which
        replaces that site's listeners with a userspace Tailscale node of its
        own. The site is then reachable at `<name>.<tailnet>` and nowhere else:
        there is no socket on any of the host's real interfaces to connect to,
        so it is off the internet by construction rather than by firewall rule.

        Directives here override the plugin's global defaults for that one node.
        The one worth setting on anything long-lived is `ephemeral false`, since
        an ephemeral node is deleted from the tailnet whenever Caddy stops and
        has to re-register on each start — which needs a valid auth key every
        time, and hands out a `-1` suffixed name if the old node has not been
        reaped yet.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.tailscaleCaddyAuth.file = "${self}/secrets/tailscale/caddy.age";

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    services = {
      caddy = {
        enable = true;
        enableReload = false;
        environmentFile = config.age.secrets.tailscaleCaddyAuth.path;

        # acme_dns makes DNS-01 the default challenge for every vhost on every
        # host, so individual proxy.nix files don't need their own tls block.
        # Our records sit behind Cloudflare's proxy, which terminates TLS and
        # won't negotiate acme-tls/1, so TLS-ALPN-01 can never succeed; solving
        # over DNS avoids that failed attempt on issuance and every renewal.
        # CF_API_TOKEN comes from the environmentFile secret above, and the
        # token needs Zone:DNS:Edit + Zone:Zone:Read on every zone we serve.
        globalConfig = ''
          tailscale {
            ephemeral true
            ${tailscaleNodes}
          }

          acme_dns cloudflare {env.CF_API_TOKEN}

          # Public traffic arrives through Cloudflare's proxy, so the peer
          # address Caddy sees is a Cloudflare edge rather than the visitor.
          # Without this, `{client_ip}` and the access log's `client_ip` field
          # both name Cloudflare — which would make the fail2ban caddy jail ban
          # Cloudflare's edge and take every site here off the internet for
          # everyone at once. Trusting the ranges above lets Caddy read the
          # real address out of CF-Connecting-IP, which Cloudflare sets itself
          # and strips from inbound requests, so a client cannot forge it.
          #
          # Tailnet-bound vhosts are unaffected: their peer is a tailnet
          # address, matches none of these ranges, and stays its own client_ip.
          servers {
            trusted_proxies static ${lib.concatStringsSep " " cloudflareRanges}
            client_ip_headers CF-Connecting-IP
          }
        '';

        package = pkgs.caddy.withPlugins {
          plugins = [
            # curl -s https://proxy.golang.org/github.com/tailscale/caddy-tailscale/@latest
            "github.com/tailscale/caddy-tailscale@v0.0.0-20260106222316-bb080c4414ac"
            # https://github.com/caddy-dns/cloudflare/tags
            "github.com/caddy-dns/cloudflare@v0.2.4"
          ];
          hash = "sha256-TAg2e7r6du1b2CY81x63yGPJ59mjvzdOKcuno+Klaa8=";
        };
      };

      tailscale.permitCertUid = "caddy";
    };
  };
}
