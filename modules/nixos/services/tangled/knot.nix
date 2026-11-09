{
  config,
  lib,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.tangled.knot;
  networkMap = config.mySnippets.biscuits-at.networkMap;
  tailscale = config.myNixOS.services.tailscale;
  tailnetIP = tailscale.address;
in
{
  options.myNixOS.services.tangled.knot.enable =
    lib.mkEnableOption "Tangled knot, the git server behind knot.biscuits.at";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.tailscale.enable && tailnetIP != null;
        message = ''
          myNixOS.services.tangled.knot binds its SSH server to this host's
          tailnet address and nowhere else, so the host has to run Tailscale
          and appear in mySnippets.tailnet.tailscaleIPs.
        '';
      }
    ];

    # The tailnet address only exists once tailscaled is Running. The nixpkgs
    # unit sets its own start limit, so the shared values are forced.
    systemd.services.knot-rs = lib.recursiveUpdate tailscale.bindOrdering {
      unitConfig.StartLimitIntervalSec = lib.mkForce 0;
      serviceConfig.RestartSec = lib.mkForce 5;
    };

    # KNOT_MASTER_KEY, as an environment file. It unseals the knot's signing
    # keys in /var/lib/knot/sealed-keys, and the two only work as a pair: lose
    # the key and the knot loses control of every repository's identity, leak
    # it and a copy of the sealed file is enough to sign as the knot. Owned by
    # root because systemd reads EnvironmentFile before dropping to `knot`.
    age.secrets.tangledKnot.file = "${self}/secrets/tangled/knot.age";

    # Nothing to add for backups. The knot has no database: git under
    # /var/lib/knot/repos is its whole state, ACLs included, beside the sealed
    # key file, LFS store and SSH host key, and all of it sits under /var/lib,
    # which every archive already takes.

    services.tangled.knot-rs = {
      enable = true;
      environmentFile = config.age.secrets.tangledKnot.path;

      # Upstream defaults this to true, which opens the SSH port to the world.
      # Git over SSH is tailnet-only, as Forgejo's is. The listener binds the
      # tailnet address, with this closed firewall as a second layer. Opening
      # it would also need a fail2ban jail, since this is the knot's own SSH
      # server and not OpenSSH.
      openFirewall = false;

      settings = {
        server = {
          hostname = networkMap.knot.domain;
          # The knot advertises the first admin as its owner.
          admins = [ config.myNixOS.services.tangled.owner ];
          listen_addr = "127.0.0.1:${toString networkMap.knot.port}";
          ssh_listen_addr = "${tailnetIP}:${toString networkMap.knot.sshPort}";
        };

        atproto.plc_directory = "https://plc.directory";
        contact.email = "atproto@biscuits.at";

        # The default, spelled out: closed means only admins create
        # repositories. `open` lets any atproto account host on this disk.
        acl.admission = "closed";

        # Upstream defaults to SHA-256, which GitHub and Forgejo cannot mirror
        # to or from. Fixed per repository at creation, so changing this later
        # only affects repositories made afterwards.
        git.object_format = "sha1";

        # Caddy's `client-ip` snippet replaces X-Forwarded-For with the one
        # address it resolved through Cloudflare's trusted ranges, so the
        # header is ours by the time it arrives. Without this the rate limiter
        # sees every client as 127.0.0.1 and throttles them together. Only
        # loopback is trusted to set it, so a client reaching the port some
        # other way is keyed on its real address.
        xrpc = {
          trusted_proxy_header = "x-forwarded-for";
          trusted_proxies = [
            "127.0.0.1"
            "::1"
          ];
        };

        # `legacy_admin_secret_env` is left unset on purpose. Setting it turns
        # on Basic Auth as the owner for membership writes and invite codes on
        # the public XRPC surface, a shared password standing in for the DID.
      };
    };
  };
}
