{
  config,
  lib,
  pkgs,
  self,
  ...
}:
{
  options.myNixOS.services.caddy.enable = lib.mkEnableOption "Caddy web server.";

  config = lib.mkIf config.myNixOS.services.caddy.enable {
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
        # CF_API_TOKEN comes from the environmentFile secret below, and the
        # token needs Zone:DNS:Edit + Zone:Zone:Read on every zone we serve.
        globalConfig = ''
          tailscale {
            ephemeral true
          }

          acme_dns cloudflare {env.CF_API_TOKEN}
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
