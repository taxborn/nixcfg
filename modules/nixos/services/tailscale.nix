{
  config,
  lib,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.tailscale;
in
{
  options.myNixOS.services.tailscale = {
    address = lib.mkOption {
      description = ''
        This host's address from `homelab.hosts`, or null if
        it has no entry. Read by every service that binds the tailnet address
        instead of looking the hostname up itself, and asserts on null.
      '';
      type = lib.types.nullOr lib.types.str;
      default = config.homelab.hosts.${config.networking.hostName} or null;
      readOnly = true;
    };

    bindOrdering = lib.mkOption {
      description = ''
        Unit settings for a service that binds `address`. Merge them into the
        service's `systemd.services.<name>`.

        `network.target` is up long before tailscaled has authenticated and
        been assigned an address, so a unit binding a 100.64/10 address can
        lose that race on a cold boot. `tailscaled-autoconnect` is the unit
        that waits for the backend to be Running, so ordering after it wins the
        race rather than merely improving the odds the way
        `tailscaled.service` does.

        A losing attempt still dies with EADDRNOTAVAIL, for instance on a
        laptop that has never joined the tailnet. systemd's default limit of
        five starts in ten seconds then latches the unit failed after a few
        seconds and leaves it dead until someone notices. Dropping the limit
        and retrying every five seconds turns that into a short wait.
      '';
      type = lib.types.attrs;
      default = {
        after = [ "tailscaled-autoconnect.service" ];
        wants = [ "tailscaled-autoconnect.service" ];
        unitConfig.StartLimitIntervalSec = 0;
        serviceConfig.RestartSec = 5;
      };
      readOnly = true;
    };

    operator = lib.mkOption {
      description = ''
        Unix user handed control of tailscaled, so `tailscale status` and the
        rest of the CLI work without sudo. Null leaves them root-only.
      '';
      default = null;
      type = lib.types.nullOr lib.types.str;
    };
  };

  config = {
    age.secrets.tailscaleAuthKey.file = "${self}/secrets/tailscale/auth.age";

    # A trusted interface is accepted before the port rules are reached, which
    # is what makes Caddy and every other socket bound to a tailnet or wildcard
    # address reachable over the tailnet without opening a port for it.
    # Loopback services are not covered, since tailnet traffic never arrives on
    # `lo`, and Caddy is the route in to them. One exception is worth
    # remembering. fail2ban hooks its chains on ahead of that accept, so its
    # ignoreIP, not this line, is what keeps a ban off the tailnet.
    # Only the trusted interface here. `openFirewall` below opens the UDP port
    # and does not touch this list.
    networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];

    services.tailscale = {
      enable = true;
      authKeyFile = config.age.secrets.tailscaleAuthKey.path;

      # `tailscale set`, not `tailscale up`. The autoconnect unit only runs
      # `up` when the backend reports NeedsLogin, NeedsMachineAuth or Stopped;
      # on a node already Running it notifies ready and exits. A flag left in
      # `extraUpFlags` therefore never reaches a machine already on the
      # tailnet, and reads one way in this file while behaving the other way on
      # the host, indefinitely. `tailscaled-set` runs on every activation, so
      # this is the half that binds.
      #
      # `--ssh` has tailscaled answer port 22 on the tailnet address itself,
      # authorising by tailnet identity. sshd is not involved on that path, so
      # `authorized_keys` is never read and `sshd_config` never consulted, and
      # anything resting on either is silently inert over the tailnet. `ssh -v`
      # reporting `Authenticated ... using "none"` is how to tell which of the
      # two answered.
      extraSetFlags = [
        "--ssh"
      ];

      # `--operator` has the same latent problem, being applied only on first
      # join. It has never changed, so it has never mattered; move it up to
      # `extraSetFlags` if it ever does.
      extraUpFlags = lib.optionals (cfg.operator != null) [
        "--operator"
        "${cfg.operator}"
      ];

      # Opens Tailscale's UDP port to the internet so peers can connect
      # directly instead of through a relay.
      openFirewall = true;
      # Enables IP forwarding so any host can advertise subnet routes or act as
      # an exit node. Whether one does is decided by the tailnet ACLs, which
      # live outside this repo.
      useRoutingFeatures = "both";
    };
  };
}
