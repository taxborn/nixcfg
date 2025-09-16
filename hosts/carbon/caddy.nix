{
  services.caddy = {
    enable = true;

    virtualHosts."taxborn.com".extraConfig = ''
      redir https://www.taxborn.com{uri} permanent
    '';
    virtualHosts."www.taxborn.com".extraConfig = ''
      respond "Hello, World!"
    '';

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
