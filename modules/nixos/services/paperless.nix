{
  config,
  lib,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.paperless;
in
{
  options.myNixOS.services.paperless.enable = lib.mkEnableOption "Paperless-ngx document management";

  config = lib.mkIf cfg.enable {
    # The initial superuser password. Read by systemd as root through
    # LoadCredential (see the nixpkgs module's paperless-scheduler preStart), so
    # it does not need to be readable by the paperless user itself.
    #
    # Only consulted while the recorded `user:password` pair differs from what
    # is in the database — changing the password in the web UI does not change
    # this file, and rotating this file resets the account back to it.
    age.secrets.paperlessAdminPassword.file = "${self}/secrets/paperless/admin-password.age";

    services.paperless = {
      enable = true;

      # Names the tailnet node Caddy answers on, and through it PAPERLESS_URL —
      # which is what Django checks CSRF origins and allauth redirects against.
      # A mismatch here does not fail at startup; it fails later, on login, with
      # a 403 that says nothing useful. The host part is the node name in
      # `hosts/helium/proxy.nix` and the two have to agree.
      domain = "paperless.${config.mySnippets.tailnet.name}";

      # Explicit, though it is also the module's default, because it is the
      # innermost of the three things keeping this off the network: granian
      # listens on loopback, so the only path in is the reverse proxy, and the
      # reverse proxy is itself bound to a tailnet-only listener. The other two
      # live in proxy.nix; this one belongs to the service.
      address = "127.0.0.1";

      passwordFile = config.age.secrets.paperlessAdminPassword.path;

      # Documents arrive by upload over the tailnet, not by dropping files into
      # a watched directory on the host, so the consumption directory stays
      # private to the service user.
      consumptionDirIsPublic = false;

      settings = {
        # Paperless polls a GitHub release endpoint on a schedule to tell the UI
        # a new version exists. Harmless in itself and still the wrong default
        # here: this host is meant to make no outbound requests on the strength
        # of holding these documents, and update checking is the one piece of
        # stock behaviour that does.
        PAPERLESS_ENABLE_UPDATE_CHECK = false;

        # The AI features send document text to a remote model endpoint to
        # suggest tags, titles, and correspondents. Upstream already defaults
        # this off (`AI_ENABLED = get_bool_from_env("PAPERLESS_AI_ENABLED",
        # "NO")`), so this pins a default rather than changing one — worth
        # pinning, because it is the single setting that would turn this host
        # into something that ships document contents off the tailnet, and a
        # default is a weaker guarantee than a decision.
        PAPERLESS_AI_ENABLED = false;

        # Classification and the search index are local, and stay on.
        PAPERLESS_ENABLE_NLTK = true;

        # How long a query waits for the write lock before giving up, in
        # seconds. Upstream's own SQLite defaults are already well chosen for
        # this — WAL, `synchronous=NORMAL`, `busy_timeout=5000`, and IMMEDIATE
        # transactions, all set in the connection's `init_command` — so readers
        # do not block writers and the nightly `sqlite3 .dump` is invisible to a
        # running consumer. What that leaves is the case where the dump is
        # walking a large database while a document is being consumed: five
        # seconds of contention is plausible there, thirty is not.
        #
        # SQLite is the engine here for the same reason Forgejo runs on it: one
        # person, one service, and a second daemon to patch and major-version
        # upgrade buys nothing at this size. Leaving `database.createLocally`
        # off is what selects it; the file lands at /var/lib/paperless/db.sqlite3
        # and is dumped into the archive from `hosts/helium`.
        PAPERLESS_DB_TIMEOUT = 30;
      };
    };
  };
}
