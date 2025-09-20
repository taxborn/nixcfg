{
  services.caddy = {
    enable = true;

    virtualHosts."mischief.town".extraConfig = ''
      redir https://www.mischief.town{uri} permanent
    '';
    virtualHosts."www.mischief.town".extraConfig = ''
      respond "Hello, World!"
    '';
  };
}
