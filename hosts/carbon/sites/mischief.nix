{
  imports = [
    ./glance.nix
  ];

  services.caddy = {
    enable = true;

    virtualHosts."mischief.town".extraConfig = ''
      redir https://www.mischief.town{uri} permanent
    '';

    # Reverse proxy to paperless-ngx on helium-01 via Tailscale
    # Only accessible from Tailscale network (100.64.0.0/10)
    virtualHosts."docs.mischief.town".extraConfig = ''
      # Define matcher for Tailscale IP range
      @tailscale {
        remote_ip 100.64.0.0/10
      }

      # Only allow Tailscale clients
      handle @tailscale {
        reverse_proxy http://100.64.0.0:21594 {
          header_up Host {upstream_hostport}
          header_up X-Real-IP {remote_host}
          header_up X-Forwarded-For {remote_host}
          header_up X-Forwarded-Proto {scheme}
        }
      }

      # Deny all other traffic
      handle {
        respond "Access denied: Tailscale required" 403
      }
    '';
  };
}
