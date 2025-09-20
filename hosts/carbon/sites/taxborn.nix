{
  services.caddy = {
    enable = true;

    virtualHosts."taxborn.com".extraConfig = ''
      redir https://www.taxborn.com{uri} permanent
    '';
    virtualHosts."www.taxborn.com".extraConfig = ''
      respond "Hello, World!"
    '';

    virtualHosts."braxtonfair.com".extraConfig = ''
      redir https://www.braxtonfair.com{uri} permanent
    '';
    virtualHosts."www.braxtonfair.com".extraConfig = ''
      redir https://www.taxborn.com{uri} permanent
    '';
  };
}
