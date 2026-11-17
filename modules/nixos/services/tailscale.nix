{
  config,
  lib,
  self,
  ...
}:
{
  options.homelab.tailscale = {
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

  };

  config = {
    age.secrets.tailscaleAuthKey.file = "${self}/secrets/tailscale/auth.age";

    networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];

    services.tailscale = {
      enable = true;
      authKeyFile = config.age.secrets.tailscaleAuthKey.path;

      # `tailscale set` applies on every activation. `up` flags only apply on first join.
      extraSetFlags = [
        "--ssh"
      ];

      extraUpFlags = [
        "--operator"
        config.homelab.owner.username
      ];

      openFirewall = true;
      useRoutingFeatures = "both";
    };
  };
}
