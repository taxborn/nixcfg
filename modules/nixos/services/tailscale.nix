{
  config,
  lib,
  self,
  ...
}:
{
  options.homelab.tailscale = {
    address = lib.mkOption {
      description = "This host's tailnet address from `homelab.hosts`, or null.";
      type = lib.types.nullOr lib.types.str;
      default = config.homelab.hosts.${config.networking.hostName} or null;
      readOnly = true;
    };

    bindOrdering = lib.mkOption {
      description = "Unit settings for a service that binds `address`. See docs/network.md#tailscale.";
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
