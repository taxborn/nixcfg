{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.tranquil-pds;
  networkMap = config.mySnippets.biscuits-at.networkMap;

  # `main`, not the tagged release nixpkgs carries -- see the `tranquil-src`
  # input in flake.nix for what that costs. Both halves are pinned from the
  # same source tree on purpose: the server serves the frontend out of
  # `settings.frontend.dir`, so letting one come from the flake and the other
  # from nixpkgs is a version skew that only shows up as a broken web UI.
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  options.myNixOS.services.tranquil-pds.enable = lib.mkEnableOption "Tranquil AT Protocol PDS";

  config = lib.mkIf cfg.enable {
    age.secrets.tranquilPds.file = "${self}/secrets/tranquil-pds.age";

    services.tranquil-pds = {
      enable = true;
      package = packages.tranquil-pds;

      # Postgres, not the embedded `tranquil-store`. Tranquil's own docs call
      # that one experimental with a risk of total data loss, and there is no
      # migration between the two in either direction — picking it now would
      # mean a fresh instance and a repo migration to get back off it.
      database.createLocally = true;

      # JWT_SECRET, DPOP_SECRET, MASTER_KEY, and the Fastmail SMTP login. These
      # cannot go in `settings`: that renders to a world-readable file in the
      # nix store. MASTER_KEY in particular is what every account's signing key
      # is encrypted under, so losing it loses the repositories and leaking it
      # hands over the identities.
      environmentFiles = [ config.age.secrets.tranquilPds.path ];

      settings = {
        frontend.dir = packages.tranquil-pds-frontend;

        server = {
          hostname = networkMap.pds.domain;
          port = networkMap.pds.port;

          # Handles are registered as `<name>.pds.biscuits.at`. Resolution is
          # over HTTP, not DNS: a client asks
          # `https://<handle>/.well-known/atproto-did` and Tranquil answers off
          # the Host header. So every handle ever issued has to reach this
          # service over TLS a browser accepts — which is what the wildcard DNS
          # record and the `*.pds.biscuits.at` vhost exist for, and why neither
          # can go behind Cloudflare's proxy.
          user_handle_domains = [ networkMap.pds.domain ];

          # Left at its default, spelled out because it is the difference
          # between a personal PDS and an open one. The first code is printed
          # to the journal on first start; `journalctl -u tranquil-pds` is where
          # to find it.
          invite_code_required = true;

          # One reverse proxy in front (Caddy), terminating TLS. Tranquil infers
          # exactly this when it is not terminating TLS itself, so the value is
          # the default rather than a correction — but it decides which entry of
          # `X-Forwarded-For` becomes the client address for rate limiting and
          # device records, and getting it wrong there fails silently.
          trusted_proxy_count = 1;
        };

        # Account verification and PLC operations need a way to reach a person.
        # Fastmail as a smarthost, the same relay Vaultwarden and Forgejo use,
        # rather than direct MX: this host has no reverse DNS worth speaking of
        # and mail from a fresh subdomain gets filed as spam on sight.
        #
        # Port 465 is implicit TLS, not STARTTLS. MAIL_SMARTHOST_USERNAME and
        # MAIL_SMARTHOST_PASSWORD come from the environment file — Tranquil
        # refuses to start with a password set alongside `tls = "none"`, but
        # nothing stops it shipping one from the nix store, so keep both halves
        # of the login there.
        #
        # The sender is the apex address the other two services already use,
        # not one on `pds.biscuits.at`. As far as mail is concerned that
        # subdomain is a domain of its own: the zone's SPF record and its three
        # `_domainkey` DKIM CNAMEs sit at `biscuits.at` and do not descend, so
        # sending as `pds.biscuits.at` means unauthenticated mail until the
        # subdomain is added to Fastmail with records of its own.
        email = {
          from_address = "infra@biscuits.at";
          from_name = "biscuits.at PDS";
          smarthost = {
            host = "smtp.fastmail.com";
            port = 465;
            tls = "implicit";
          };
        };
      };
    };
  };
}
