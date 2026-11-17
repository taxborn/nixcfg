{ config, ... }:
let
  networkMap = config.homelab.services;

  # Drops credentials before the line is written. See docs/network.md#access-logs.
  accessLog = name: ''
    output file /var/log/caddy/direct-${name}.log {
      mode 0640
    }
    format filter {
      wrap json
      fields {
        request>headers>Authorization delete
        request>headers>Proxy-Authorization delete
        request>headers>Cookie delete
        resp_headers>Set-Cookie delete
        request>uri query {
          replace code REDACTED
          replace state REDACTED
          replace token REDACTED
        }
      }
    }
  '';
in
{
  homelab.caddy = {
    cloudflareOnly = true;

    directVHosts = [
      networkMap.pds.domain
      "*.${networkMap.pds.domain}"
    ];
  };

  networking.firewall.allowedUDPPorts = [ 443 ];

  services.caddy.virtualHosts = {
    "biscuits.at".extraConfig = ''
      import cloudflare-mtls

      redir https://${networkMap.glance.domain}{uri} permanent
    '';
    ${networkMap.glance.domain}.extraConfig = ''
      import cloudflare-mtls

      reverse_proxy 127.0.0.1:${toString networkMap.glance.port} {
        import client-ip
      }
    '';

    ${networkMap.ntfy.domain}.extraConfig = ''
      import cloudflare-mtls

      reverse_proxy 127.0.0.1:${toString networkMap.ntfy.port} {
        import client-ip
      }
    '';

    ${networkMap.piper.domain}.extraConfig = ''
      import cloudflare-mtls

      encode zstd gzip

      reverse_proxy 127.0.0.1:${toString networkMap.piper.port} {
        import client-ip
      }
    '';

    ${networkMap.atuin.domain}.extraConfig = ''
      import cloudflare-mtls

      encode zstd gzip

      reverse_proxy 127.0.0.1:${toString networkMap.atuin.port} {
        import client-ip
      }
    '';

    ${networkMap.vaultwarden.domain}.extraConfig = ''
      import cloudflare-mtls

      encode zstd gzip
      reverse_proxy 127.0.0.1:${toString networkMap.vaultwarden.port} {
        import client-ip
      }
    '';

    # `{remote_host}` is the TCP peer. `header_up` replaces, so a forged X-Forwarded-For never reaches the PDS.
    ${networkMap.pds.domain} = {
      logFormat = accessLog networkMap.pds.domain;

      extraConfig = ''
        encode zstd gzip

        reverse_proxy 127.0.0.1:${toString networkMap.pds.port} {
          header_up X-Forwarded-For {remote_host}
          header_up X-Real-IP {remote_host}
        }
      '';
    };

    "*.${networkMap.pds.domain}" = {
      logFormat = accessLog "wildcard.${networkMap.pds.domain}";

      extraConfig = ''
        encode zstd gzip

        import cloudflare-dns

        # Same as the apex above, for the same reason.
        reverse_proxy 127.0.0.1:${toString networkMap.pds.port} {
          header_up X-Forwarded-For {remote_host}
          header_up X-Real-IP {remote_host}
        }
      '';
    };

    ${networkMap.knot.domain}.extraConfig = ''
      import cloudflare-mtls

      reverse_proxy 127.0.0.1:${toString networkMap.knot.port} {
        import client-ip
      }
    '';
  };
}
