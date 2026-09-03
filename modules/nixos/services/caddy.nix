{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.caddy;

  # https://www.cloudflare.com/ips-v4 / https://www.cloudflare.com/ips-v6
  # Under `cloudflareOnly` these are the only addresses allowed to reach
  # Caddy on 80/443: anyone else is talking to the origin directly, past the
  # proxy and the WAF. Cloudflare publishes additions here, and a range we
  # have not copied over yet is a partial outage that reads as their fault.
  cloudflareIPv4Ranges = [
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
  ];
  cloudflareIPv6Ranges = [
    "2400:cb00::/32"
    "2606:4700::/32"
    "2803:f800::/32"
    "2405:b500::/32"
    "2405:8100::/32"
    "2a06:98c0::/29"
    "2c0f:f248::/32"
  ];
in
{
  options.myNixOS.services.caddy = {
    enable = lib.mkEnableOption "Caddy web server.";

    cloudflareOnly = lib.mkEnableOption ''
      dropping 80/443 from everywhere but Cloudflare's edge.

      Only true where every vHost is proxied. A host serving anything on a
      LAN or a bare public IP goes dark otherwise
    '';
  };

  config = lib.mkIf cfg.enable {
    age.secrets.tailscaleCaddyAuth.file = "${self}/secrets/tailscale/caddy.age";

    networking.firewall = lib.mkMerge [
      (lib.mkIf (!cfg.cloudflareOnly) {
        allowedTCPPorts = [
          80
          443
        ];
      })

      # 80/443 stay closed to the world; only Cloudflare's edge may reach
      # them. Tailscale keeps working since its interface is trusted and
      # accepted earlier in the chain.
      #
      # `-w` matches the ip46tables wrapper the rest of the ruleset goes
      # through. Without it a fail2ban ban landing mid-reload holds the
      # xtables lock, firewall-start exits non-zero under `sh -e`, and
      # firewall-stop then unhooks nixos-fw from INPUT entirely.
      (lib.mkIf cfg.cloudflareOnly {
        extraCommands =
          lib.concatMapStrings (range: ''
            iptables -w -A nixos-fw -p tcp -s ${range} -m multiport --dports 80,443 -j nixos-fw-accept
          '') cloudflareIPv4Ranges
          + lib.concatMapStrings (range: ''
            ip6tables -w -A nixos-fw -p tcp -s ${range} -m multiport --dports 80,443 -j nixos-fw-accept
          '') cloudflareIPv6Ranges;
      })
    ];

    services = {
      caddy = {
        enable = true;
        enableReload = false;
        environmentFile = config.age.secrets.tailscaleCaddyAuth.path;

        # Decides whose X-Forwarded-For {client_ip} is allowed to believe.
        # Anywhere else it falls back to the connecting address, so a direct
        # client can never spoof its own IP.
        globalConfig = lib.optionalString cfg.cloudflareOnly ''
          servers {
            trusted_proxies static ${lib.concatStringsSep " " (cloudflareIPv4Ranges ++ cloudflareIPv6Ranges)}
          }
        '';

        # Hands every backend one authoritative client IP. Caddy appends the
        # peer to X-Forwarded-For rather than replacing it, and never sends
        # X-Real-IP at all, so Forgejo (REVERSE_PROXY_LIMIT=1) and Vaultwarden
        # (IP_HEADER=X-Real-IP) otherwise resolve Cloudflare's edge or the
        # loopback. Snippets must be defined before the vHosts that import
        # them, which is where extraConfig lands.
        extraConfig = ''
          (client-ip) {
            header_up X-Forwarded-For {client_ip}
            header_up X-Real-IP {client_ip}
          }
        '';

        package = pkgs.caddy.withPlugins {
          plugins = [
            # curl -s https://proxy.golang.org/github.com/tailscale/caddy-tailscale/@latest
            "github.com/tailscale/caddy-tailscale@v0.0.0-20260826180304-de41b249af4f"
            # https://github.com/caddy-dns/cloudflare/tags
            "github.com/caddy-dns/cloudflare@v0.2.4"
          ];
          hash = "sha256-qznZBLjAnDjjopl8Pmt4HfIPYB+hp/SLNk5h2v+u6B0=";
        };
      };

      tailscale.permitCertUid = "caddy";
    };
  };
}
