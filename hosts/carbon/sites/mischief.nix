{
  imports = [
    ./glance.nix
  ];

  services.caddy = {
    enable = true;

    virtualHosts."mischief.town".extraConfig = ''
      redir https://www.mischief.town{uri} permanent
    '';

    virtualHosts."docs.mischief.town".extraConfig = ''reverse_proxy http://100.64.1.0:21594'';
  };
}
