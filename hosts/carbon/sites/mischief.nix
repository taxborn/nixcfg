{
  imports = [
    ./glance.nix
  ];

  services.caddy = {
    enable = true;

    virtualHosts."mischief.town".extraConfig = ''
      redir https://www.mischief.town{uri} permanent
    '';
  };
}
