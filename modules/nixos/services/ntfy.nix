{
  config,
  lib,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.ntfy;
  networkMap = config.mySnippets.biscuits-at.networkMap;
in
{
  options.myNixOS.services.ntfy.enable = lib.mkEnableOption "ntfy push notification server";

  config = lib.mkIf cfg.enable {
    # NTFY_AUTH_USERS, NTFY_AUTH_ACCESS and NTFY_AUTH_TOKENS. Users carry
    # bcrypt hashes and tokens are bearer credentials, so none of it can go in
    # `settings`, which renders to a world-readable file in the nix store.
    age.secrets.ntfy.file = "${self}/secrets/ntfy.age";

    services.ntfy-sh = {
      enable = true;
      environmentFile = config.age.secrets.ntfy.path;

      settings = {
        base-url = "https://${networkMap.ntfy.domain}";
        # Loopback, so Caddy is the only route in. The module's default is
        # `[::1]:2586`, which the shared port registry would not know about.
        listen-http = "127.0.0.1:${toString networkMap.ntfy.port}";

        # Believe X-Forwarded-For for rate limiting. Safe here for the same
        # reason it is on the other vhosts: Caddy's `client-ip` snippet
        # replaces the header with the one address it trusts.
        behind-proxy = true;

        # Anyone who can reach the vhost could otherwise publish to or read
        # any topic, since ntfy's default is read-write for everyone. Every
        # user, ACL entry and token is provisioned declaratively from the
        # secret above, so nothing is created through the CLI.
        auth-default-access = "deny-all";
        enable-login = true;

        # Not `upstream-base-url`. Setting it sends poll requests through
        # ntfy.sh, which is what makes iOS push work on a self-hosted server,
        # and it is the one thing here that would talk to a third party. The
        # Android app holds its own connection and needs none of it.
      };
    };

    # Users, tokens and ACLs are rebuilt from the secret on every start and the
    # message cache is disposable, so the state directory holds nothing worth
    # archiving. It also holds two live SQLite files, which the backup module
    # exists to keep out of archives as a torn copy. DynamicUser puts the real
    # directory under /var/lib/private, and `/var/lib/ntfy-sh` is a symlink to
    # it, which borg records as a link rather than following.
    myNixOS.services.backups.client.extraExcludes =
      lib.mkIf config.myNixOS.services.backups.client.enable
        [
          "/var/lib/private/ntfy-sh"
        ];
  };
}
