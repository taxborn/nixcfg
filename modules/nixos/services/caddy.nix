{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.homelab.caddy;

  originPullCert = "${self}/keys/cloudflare-origin-pull.pem";

  unprotectedVHosts = lib.subtractLists cfg.directVHosts (
    lib.attrNames (
      lib.filterAttrs (
        _: vhost: !lib.hasInfix "import cloudflare-mtls" vhost.extraConfig
      ) config.services.caddy.virtualHosts
    )
  );

  usesDnsChallenge = lib.any (vhost: lib.hasInfix "import cloudflare-dns" vhost.extraConfig) (
    lib.attrValues config.services.caddy.virtualHosts
  );

  # One direct vHost reopens 80/443 to everyone. See docs/network.md.
  edgeOnly = cfg.cloudflareOnly && cfg.directVHosts == [ ];

  # Re-check with `just check-cloudflare-ips`. A missing range is a partial outage.
  cloudflareIPv4Ranges = [
    "173.245.48.0/20"
    "103.21.244.0/22"
    "103.22.200.0/22"
    "103.31.4.0/22"
    "141.101.64.0/18"
    "108.162.192.0/18"
    "190.93.240.0/20"
    "188.114.96.0/20"
    "197.234.240.0/22"
    "198.41.128.0/17"
    "162.158.0.0/15"
    "104.16.0.0/13"
    "104.24.0.0/14"
    "172.64.0.0/13"
    "131.0.72.0/22"
  ];
  cloudflareIPv6Ranges = [
    "2400:cb00::/32"
    "2606:4700::/32"
    "2803:f800::/32"
    "2405:b500::/32"
    "2405:8100::/32"
    "2a06:98c0::/29"
    "2c0f:f248::/32"
  ];
in
{
  options.homelab.caddy = {
    cloudflareOnly = lib.mkEnableOption ''
      dropping 80/443 from everywhere but Cloudflare's edge.

      Only true where every vHost is proxied. A host serving anything on a
      LAN or a bare public IP goes dark otherwise
    '';

    tailnetOnly = lib.mkEnableOption ''
      keeping 80/443 off the firewall entirely, leaving Caddy reachable over
      the tailnet and nowhere else.

      The opposite end of `cloudflareOnly`: that one narrows the two ports to
      the edge, this one closes them. Nothing is punched through for the
      tailnet because nothing needs to be — its interface is already trusted,
      and accepted before the port rules are reached.

      Costs the host HTTP-01, which needs an open 80 from anywhere. Every vHost
      on a `tailnetOnly` host has to solve DNS-01 instead, and one that does not
      fails issuance in a retry loop rather than loudly
    '';

    directVHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = lib.literalExpression ''[ "pds.biscuits.at" ]'';
      description = ''
        vHosts reached straight from the internet rather than through
        Cloudflare, exempting them from the `cloudflare-mtls` assertion.

        Naming one costs the whole host its IP allowlist: 80/443 reopen to
        everyone, because iptables cannot tell which name a connection is
        about to ask for. The other vHosts keep the client-certificate half,
        which is the half that actually authenticates, and lose the
        belt-and-braces half.

        Worth it only where the proxy cannot serve the name at all. The PDS is
        the case this exists for — see hosts/argon/proxy.nix.
      '';
    };
  };

  config = {
    assertions =
      lib.optional cfg.cloudflareOnly {
        assertion = unprotectedVHosts == [ ];
        message = ''
          These vHosts do not `import cloudflare-mtls`, so they answer to any
          client that reaches the port, not just Cloudflare: ${lib.concatStringsSep ", " unprotectedVHosts}.

          If that is deliberate, list them in `directVHosts` and read what it
          costs the rest of the host.
        '';
      }
      ++ lib.optional cfg.tailnetOnly {
        assertion = !cfg.cloudflareOnly;
        message = ''
          `cloudflareOnly` and `tailnetOnly` are two answers to the same question
          about 80/443 — narrow them to Cloudflare's edge, or close them. Enabling
          both silently gives you the second, plus an mTLS assertion about vHosts
          no client outside the tailnet can reach.
        '';
      };

    # The token can edit DNS, so it is only decrypted where a vHost solves DNS-01.
    age.secrets = lib.mkIf usesDnsChallenge {
      cloudflareDnsToken.file = "${self}/secrets/cloudflare/dns-token.age";
    };

    networking.firewall = lib.mkMerge [
      (lib.mkIf (!edgeOnly && !cfg.tailnetOnly) {
        allowedTCPPorts = [
          80
          443
        ];
      })

      # `-w` waits for the xtables lock. Without it a concurrent fail2ban ban can unhook nixos-fw.
      (lib.mkIf edgeOnly {
        extraCommands =
          lib.concatMapStrings (range: ''
            iptables -w -A nixos-fw -p tcp -s ${range} -m multiport --dports 80,443 -j nixos-fw-accept
          '') cloudflareIPv4Ranges
          + lib.concatMapStrings (range: ''
            ip6tables -w -A nixos-fw -p tcp -s ${range} -m multiport --dports 80,443 -j nixos-fw-accept
          '') cloudflareIPv6Ranges;
      })
    ];

    services = {
      caddy = {
        enable = true;
        enableReload = false;
        environmentFile = lib.mkIf usesDnsChallenge config.age.secrets.cloudflareDnsToken.path;

        # Strict mode reads X-Forwarded-For right to left, so a visitor cannot spoof its address.
        globalConfig = lib.optionalString cfg.cloudflareOnly ''
          servers {
            trusted_proxies static ${lib.concatStringsSep " " (cloudflareIPv4Ranges ++ cloudflareIPv6Ranges)}
            trusted_proxies_strict
          }
        '';

        extraConfig = ''
          (client-ip) {
            header_up X-Forwarded-For {client_ip}
            header_up X-Real-IP {client_ip}
          }
        ''
        + ''
          (cloudflare-dns) {
            tls {
              dns cloudflare {env.CF_API_TOKEN}
            }
          }
        ''
        # Proves the request came from this zone, not just from Cloudflare. Every vHost must import it.
        + lib.optionalString cfg.cloudflareOnly ''
          (cloudflare-mtls) {
            tls {
              client_auth {
                mode require_and_verify
                trust_pool file ${originPullCert}
              }
            }
          }
        '';

        package = pkgs.caddy.withPlugins {
          plugins = [
            "github.com/caddy-dns/cloudflare@v0.2.4"
          ];
          hash = "sha256-QSiwKqKvSxhksWBF4/MlBOpyXba5xOQ2sRwA0R7399E=";
        };
      };
    };
  };
}
