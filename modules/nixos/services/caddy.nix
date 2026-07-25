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

        globalConfig = ''
          tailscale {
            ephemeral true
          }
        '';

        package = pkgs.caddy.withPlugins {
          plugins = [
            # curl -s https://proxy.golang.org/github.com/tailscale/caddy-tailscale/@latest
            "github.com/tailscale/caddy-tailscale@v0.0.0-20260106222316-bb080c4414ac"
            # https://github.com/caddy-dns/cloudflare/tags
            "github.com/caddy-dns/cloudflare@v0.2.4"
          ];
          hash = "sha256-OwSvmqoGGGRHi1akpwxk5UMhEVJGaDnr6zjjGqVVwkA=";
        };
      };

      tailscale.permitCertUid = "caddy";
    };
  };
}
