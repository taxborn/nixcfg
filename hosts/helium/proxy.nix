{ config, ... }:
let
  networkMap = config.mySnippets.biscuits-at.networkMap;
in
{
  # Helium serves two names and neither is meant for the internet, so the two
  # ports stay shut and the tailnet interface is the whole front door.
  myNixOS.services.caddy.tailnetOnly = true;

  services.caddy.virtualHosts = {
    # Paperless. `docs.biscuits.at` is a public A record holding Helium's
    # tailnet address, which is why this is a real certificate on a name that
    # routes nowhere: anyone can resolve it, only the tailnet can connect, and
    # the browser is still satisfied.
    #
    # That address is also why the certificate has to come over DNS-01. HTTP-01
    # and TLS-ALPN both need Let's Encrypt to reach the host on a routable
    # address, and 100.64/10 is not one. CF_API_TOKEN comes from Caddy's
    # environmentFile, the same token the PDS wildcard on Argon uses, which
    # already carries Zone:DNS:Edit on this zone.
    #
    # An explicit record beats the zone's proxied `*.biscuits.at`, so this name
    # never reaches Cloudflare's edge and needs no `cloudflare-mtls`.
    ${networkMap.paperless.domain}.extraConfig = ''
      encode zstd gzip

      tls {
        dns cloudflare {env.CF_API_TOKEN}
      }

      reverse_proxy 127.0.0.1:${toString networkMap.paperless.port}
    '';

    # Grafana. Same arrangement as Paperless above: a public record holding
    # Helium's tailnet address, a real certificate over DNS-01, and no
    # `cloudflare-mtls` because the name never reaches Cloudflare's edge.
    ${networkMap.grafana.domain}.extraConfig = ''
      encode zstd gzip

      tls {
        dns cloudflare {env.CF_API_TOKEN}
      }

      reverse_proxy 127.0.0.1:${toString networkMap.grafana.port}
    '';

    # AdGuard Home's UI. Same arrangement as Grafana above.
    ${networkMap.adguard.domain}.extraConfig = ''
      encode zstd gzip

      tls {
        dns cloudflare {env.CF_API_TOKEN}
      }

      reverse_proxy 127.0.0.1:${toString networkMap.adguard.port}
    '';
  };
}
