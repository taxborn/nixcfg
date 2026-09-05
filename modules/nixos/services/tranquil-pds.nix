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

  # `main`, not the tagged release nixpkgs carries. The `tranquil-src` input in
  # flake.nix records what tracking main costs. Server and frontend come from
  # the same tree on purpose: the server serves the frontend out of
  # `settings.frontend.dir`, so taking one from the flake and the other from
  # nixpkgs is a version skew that shows up only as a broken web UI.
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  options.myNixOS.services.tranquil-pds.enable = lib.mkEnableOption "Tranquil AT Protocol PDS";

  config = lib.mkIf cfg.enable {
    # Tranquil's repository store. A logical dump rather than the live data
    # directory, for the reason the option documents, and it covers the
    # whole instance: every account's repo, its encrypted signing key, and
    # the firehose sequence live in postgres. Blobs do not. Those sit under
    # /var/lib/tranquil-pds/blobs and ride along in the archive.
    myNixOS.services.backups.client.postgresqlDumpAll =
      lib.mkIf config.myNixOS.services.backups.client.enable true;

    age.secrets.tranquilPds.file = "${self}/secrets/tranquil-pds.age";

    services.tranquil-pds = {
      enable = true;
      package = packages.tranquil-pds;

      # Postgres, not the embedded `tranquil-store`. Tranquil's own docs call
      # that one experimental with a risk of total data loss, and nothing
      # migrates between the two in either direction. Switching later means a
      # fresh instance and a repo migration.
      database.createLocally = true;

      # JWT_SECRET, DPOP_SECRET, MASTER_KEY, and the Fastmail login. None can go
      # in `settings`, which renders to a world-readable file in the nix store.
      # MASTER_KEY encrypts every account's signing key: lose it and the
      # repositories are gone, leak it and the identities are.
      environmentFiles = [ config.age.secrets.tranquilPds.path ];

      settings = {
        frontend.dir = packages.tranquil-pds-frontend;

        server = {
          hostname = networkMap.pds.domain;
          port = networkMap.pds.port;

          # Handles are registered as `<name>.pds.biscuits.at` and resolved over
          # HTTP, not DNS: a client asks
          # `https://<handle>/.well-known/atproto-did` and Tranquil answers off
          # the Host header. Every handle ever issued therefore has to reach
          # this service over TLS a browser accepts, which is what the wildcard
          # DNS record and the `*.pds.biscuits.at` vhost exist for, and why
          # neither can go behind Cloudflare's proxy.
          user_handle_domains = [ networkMap.pds.domain ];

          # The default, spelled out because it is the line between a personal
          # PDS and an open one. The first code goes to the journal on first
          # start: `journalctl -u tranquil-pds`.
          invite_code_required = true;

          # One reverse proxy in front (Caddy), terminating TLS. Tranquil infers
          # exactly this when it is not terminating TLS itself, so the value is
          # the default rather than a correction. It picks which entry of
          # `X-Forwarded-For` becomes the client address for rate limiting and
          # device records, and a wrong value fails silently.
          trusted_proxy_count = 1;
        };

        # Account verification and PLC operations need a way to reach a person.
        # Fastmail as a smarthost rather than direct MX: this host has no
        # reverse DNS worth speaking of, and mail from a fresh subdomain gets
        # filed as spam on sight. Port 465 is implicit TLS, not STARTTLS.
        #
        # The sender is the apex address the other services already use, not one
        # on `pds.biscuits.at`. As far as mail is concerned that subdomain is a
        # domain of its own: the zone's SPF record and its `_domainkey` DKIM
        # CNAMEs sit at `biscuits.at` and do not descend, so sending as
        # `pds.biscuits.at` means unauthenticated mail.
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
