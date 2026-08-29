{
  self,
  config,
  lib,
  ...
}:
let
  cfg = config.myNixOS.services.tranquil-pds;
  networkMap = config.mySnippets.mischief-town.networkMap;
in
{
  # Unconditional, like every other flake-provided module in this repo: it adds
  # options and nothing else until `services.tranquil-pds.enable` is set, and
  # `self.nixosModules` is the only argument these modules are written against.
  imports = [ self.nixosModules.tranquil-pds ];

  options.myNixOS.services.tranquil-pds.enable = lib.mkEnableOption "Tranquil AT Protocol PDS";

  config = lib.mkIf cfg.enable {
    age.secrets.tranquilPds.file = "${self}/secrets/tranquil-pds/secrets.age";

    # Tranquil's CI builds the server and frontend and pushes them here, and the
    # flake input keeps Tranquil's own nixpkgs pin so that what we ask for is
    # the store path CI publishes rather than a rebuild of it.
    #
    # Do not count on it. The cache had nothing for the pinned revision when
    # this went in, server or frontend, so the first build of any given bump is
    # a full Rust compile — done on the workstation and copied over, which is
    # what `just update carbon` does anyway. This entry costs nothing and starts
    # paying the moment CI catches up.
    nix.settings = {
      substituters = [ "https://tranquil.cachix.org" ];
      trusted-public-keys = [
        "tranquil.cachix.org-1:PoO+mGL6a6LcJiPakMDHN4E218/ei/7v2sxeDtNkSRg="
      ];
    };

    services.tranquil-pds = {
      enable = true;

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
        server = {
          hostname = networkMap.pds.domain;
          port = networkMap.pds.port;

          # Handles are registered as `<name>.pds.mischief.town`. Resolution is
          # over HTTP, not DNS: a client asks
          # `https://<handle>/.well-known/atproto-did` and Tranquil answers off
          # the Host header. So every handle ever issued has to reach this
          # service over TLS a browser accepts — which is what the wildcard DNS
          # record and the `*.pds.mischief.town` vhost exist for, and why
          # neither can go behind Cloudflare's proxy.
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
        # The sender is on `pds.mischief.town`, not the apex, and that is a
        # domain of its own as far as mail is concerned: the zone's SPF record
        # and the three `_domainkey` DKIM CNAMEs all sit at `mischief.town` and
        # do not descend. Until `pds.mischief.town` is added as a domain in
        # Fastmail with its own SPF and DKIM records, submission is rejected or
        # the mail is unauthenticated on arrival.
        email = {
          from_address = "admin@${networkMap.pds.domain}";
          from_name = "mischief.town PDS";
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
