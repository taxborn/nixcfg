{
  imports = [
    ./sites/mischief.nix
    ./sites/taxborn.nix
    ./sites/vaultwarden.nix
  ];

  services.caddy = {
    enable = true;

    virtualHosts."ticker.blue".extraConfig = ''
      redir https://www.ticker.blue{uri} permanent
    '';
    virtualHosts."www.ticker.blue".extraConfig = ''
      respond "Hello, World!"
    '';

  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
