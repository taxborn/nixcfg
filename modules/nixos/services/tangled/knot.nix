{
  config,
  lib,
  self,
  ...
}:
let
  networkMap = config.homelab.services;
  tailscale = config.homelab.tailscale;
  tailnetIP = tailscale.address;
in
{
  assertions = [
    {
      assertion = config.services.tailscale.enable && tailnetIP != null;
      message = ''
        homelab.tangled.knot binds its SSH server to this host's
        tailnet address and nowhere else, so the host has to run Tailscale
        and appear in homelab.hosts.
      '';
    }
  ];

  systemd.services.knot-rs = lib.recursiveUpdate tailscale.bindOrdering {
    unitConfig.StartLimitIntervalSec = lib.mkForce 0;
    serviceConfig.RestartSec = lib.mkForce 5;
  };

  # Lose this and the knot loses every repository's identity.
  age.secrets.tangledKnot.file = "${self}/secrets/tangled/knot.age";

  services.tangled.knot-rs = {
    enable = true;
    environmentFile = config.age.secrets.tangledKnot.path;

    # Upstream opens the SSH port to the world. Git over SSH is tailnet-only.
    openFirewall = false;

    settings = {
      server = {
        hostname = networkMap.knot.domain;
        admins = [ config.homelab.owner.did ];
        listen_addr = "127.0.0.1:${toString networkMap.knot.port}";
        ssh_listen_addr = "${tailnetIP}:${toString networkMap.knot.sshPort}";
      };

      atproto.plc_directory = "https://plc.directory";
      contact.email = config.homelab.mail.atproto;

      acl.admission = "closed";

      # GitHub cannot mirror SHA-256. Fixed per repository at creation.
      git.object_format = "sha1";

      xrpc = {
        trusted_proxy_header = "x-forwarded-for";
        trusted_proxies = [
          "127.0.0.1"
          "::1"
        ];
      };

      # `legacy_admin_secret_env` stays unset. It enables Basic Auth as the owner.
    };
  };
}
