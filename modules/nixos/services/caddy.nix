{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.caddy;

  # Public half of the certificate Cloudflare presents on every origin pull.
  # The private half lives only in Cloudflare; nothing here needs it, and
  # rotating means generating a fresh pair, uploading it, and replacing this
  # file. Adding another zone means uploading this same certificate to it.
  originPullCert = "${self}/keys/cloudflare-origin-pull.pem";

  unprotectedVHosts = lib.subtractLists cfg.directVHosts (
    lib.attrNames (
      lib.filterAttrs (
        _: vhost: !lib.hasInfix "import cloudflare-mtls" vhost.extraConfig
      ) config.services.caddy.virtualHosts
    )
  );

  # Whether any vHost solves DNS-01. Derived from the vHosts rather than a
  # flag, so a vHost that imports `cloudflare-dns` cannot end up on a host
  # without the token, which fails renewal in a retry loop instead of loudly.
  usesDnsChallenge = lib.any (vhost: lib.hasInfix "import cloudflare-dns" vhost.extraConfig) (
    lib.attrValues config.services.caddy.virtualHosts
  );

  # The firewall works in addresses, not names, so 80/443 can only stay shut to
  # the world while *every* vHost on the host is behind the proxy. One direct
  # vHost and the ports have to answer everyone — which is the cost
  # `directVHosts` is there to make explicit rather than accidental.
  edgeOnly = cfg.cloudflareOnly && cfg.directVHosts == [ ];

  # Under `cloudflareOnly` these are the only addresses allowed to reach Caddy
  # on 80/443: anyone else is talking to the origin directly, past the proxy
  # and the WAF. Cloudflare adds ranges from time to time, and one we have not
  # copied over yet is a partial outage that reads as their fault, so this is
  # a list to re-check rather than to trust. Refresh it with:
  #
  #   curl -s https://api.cloudflare.com/client/v4/ips \
  #     | jq -r '.result.ipv4_cidrs[], .result.ipv6_cidrs[]'
  #
  # The same lists are published as plain text at https://www.cloudflare.com/ips-v4
  # and https://www.cloudflare.com/ips-v6.
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
  options.myNixOS.services.caddy = {
    enable = lib.mkEnableOption "Caddy web server.";

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

  config = lib.mkIf cfg.enable {
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

    # The Cloudflare token can edit DNS, so it is decrypted only where a vHost
    # solves DNS-01. Carbon runs CI as root and uses HTTP-01, so it never holds
    # it. The recipients in `secrets/secrets.nix` must name the same hosts, and
    # the fleet assertion on `age.secrets` fails the build when they do not.
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

      # 80/443 stay closed to the world; only Cloudflare's edge may reach
      # them. Tailscale keeps working since its interface is trusted and
      # accepted earlier in the chain.
      #
      # `-w` matches the ip46tables wrapper the rest of the ruleset goes
      # through. Without it a fail2ban ban landing mid-reload holds the
      # xtables lock, firewall-start exits non-zero under `sh -e`, and
      # firewall-stop then unhooks nixos-fw from INPUT entirely.
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
        # One line, `CF_API_TOKEN=...`. Every vhost that cannot use HTTP-01
        # solves DNS-01 with that token, which is every certificate on Helium
        # and Argon's PDS wildcard. The file used to double as a Tailscale auth
        # key for the caddy-tailscale plugin, which is gone.
        environmentFile = lib.mkIf usesDnsChallenge config.age.secrets.cloudflareDnsToken.path;

        # Decides whose X-Forwarded-For {client_ip} is allowed to believe.
        # Anywhere else it falls back to the connecting address, so a direct
        # client can never spoof its own IP.
        #
        # `trusted_proxies_strict` is what stops a proxied client doing the
        # same. Cloudflare appends the visitor's address to the right of any
        # X-Forwarded-For the visitor sent, and Caddy reads the header left to
        # right by default, taking the first untrusted entry. A visitor who
        # sends `X-Forwarded-For: 1.2.3.4` through the proxy then becomes
        # 1.2.3.4 to Vaultwarden's, ntfy's and the knot's rate limiters. Strict
        # mode reads right to left, so the entry Cloudflare wrote wins.
        #
        # One gap remains. A visitor whose own address is inside a Cloudflare
        # range is skipped as a trusted hop, and the entry to its left is the
        # one it supplied.
        globalConfig = lib.optionalString cfg.cloudflareOnly ''
          servers {
            trusted_proxies static ${lib.concatStringsSep " " (cloudflareIPv4Ranges ++ cloudflareIPv6Ranges)}
            trusted_proxies_strict
          }
        '';

        # Hands every backend one authoritative client IP. Caddy appends the
        # peer to X-Forwarded-For rather than replacing it, and never sends
        # X-Real-IP at all, so the knot (`trusted_proxy_header`) and
        # Vaultwarden (IP_HEADER=X-Real-IP) otherwise resolve Cloudflare's edge
        # or the loopback. Snippets must be defined before the vHosts that import
        # them, which is where extraConfig lands.
        extraConfig = ''
          (client-ip) {
            header_up X-Forwarded-For {client_ip}
            header_up X-Real-IP {client_ip}
          }
        ''
        # The DNS-01 solver for vHosts Let's Encrypt cannot reach over HTTP-01:
        # names that resolve to a tailnet address, and the PDS wildcard.
        # CF_API_TOKEN comes from `environmentFile` above. Defined
        # unconditionally, since an unused snippet costs nothing and the
        # `tailnetOnly` hosts are the ones that use it.
        + ''
          (cloudflare-dns) {
            tls {
              dns cloudflare {env.CF_API_TOKEN}
            }
          }
        ''
        # The IP allowlist only proves a request came from Cloudflare's
        # network, which anyone with a Cloudflare account can arrange. This
        # proves it came from *our* zone: no client certificate, no handshake.
        # Every vHost has to import it, and the assertion below is what makes
        # forgetting one a build failure rather than an open door.
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
            # The caddy-tailscale plugin is deliberately absent. Nothing here
            # uses its `tailscale` listener, `bind tailscale/...` or its own
            # tsnet node. Core Caddy's `get_certificate tailscale` would also
            # need `services.tailscale.permitCertUid = "caddy"`, which went
            # with Forgejo's tailnet vhost, its only user.
            # https://github.com/caddy-dns/cloudflare/tags
            "github.com/caddy-dns/cloudflare@v0.2.4"
          ];
          hash = "sha256-QSiwKqKvSxhksWBF4/MlBOpyXba5xOQ2sRwA0R7399E=";
        };
      };
    };
  };
}
