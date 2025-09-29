{
  imports = [
    ./glance.nix
  ];

  services.caddy = {
    enable = true;

    virtualHosts."mischief.town".extraConfig = ''
      redir https://www.mischief.town{uri} permanent
    '';

    virtualHosts."docs.mischief.town".extraConfig = ''
      reverse_proxy http://100.64.0.0:21594 {
        header_up Host {upstream_hostport}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
      }
    '';
  };
}
