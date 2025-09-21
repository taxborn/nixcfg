{ config, ... }:

{
  imports = [
    ./sites/mischief.nix
    ./sites/taxborn.nix
    ./sites/vaultwarden.nix
  ];

  sops.secrets = {
    "cloudflare-api-key" = {
      owner = config.services.caddy.user;
      group = config.services.caddy.group;
    };
  };

  services.caddy = {
    enable = true;

    virtualHosts."ticker.blue".extraConfig = ''
      redir https://www.ticker.blue{uri} permanent
    '';
    virtualHosts."www.ticker.blue".extraConfig = ''
      respond "Hello, World!"
    '';

    extraConfig = ''
      tls {
        dns cloudflare ${config.sops.secrets."cloudflare-api-key".value}
      }
    '';
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
