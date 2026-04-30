{
  config,
  lib,
  ...
}:
{
  options.myNixOS.services.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN service";

    authKeyFile = lib.mkOption {
      description = "Key file to use for authentication";
      default = config.age.secrets.tailscaleAuthKey.path or null;
      type = lib.types.nullOr lib.types.path;
    };

    enableCaddy = lib.mkOption {
      description = "Whether to serve supported local services on Tailnet with Caddy.";
      default = true;
      type = lib.types.bool;
    };

    operator = lib.mkOption {
      description = "Tailscale operator name";
      default = "taxborn";
      type = lib.types.nullOr lib.types.str;
    };
  };

  config = lib.mkIf config.myNixOS.services.tailscale.enable {
    assertions = [
      {
        assertion = config.myNixOS.services.tailscale.authKeyFile != null;
        message = "config.tailscale.authKeyFile cannot be null.";
      }
    ];

    networking.firewall = {
      allowedUDPPorts = [ config.services.tailscale.port ];
      trustedInterfaces = [ config.services.tailscale.interfaceName ];
    };

    services.tailscale = {
      enable = true;
      inherit (config.myNixOS.services.tailscale) authKeyFile;

      extraUpFlags = [
        "--ssh"
      ]
      ++ lib.optionals (config.myNixOS.services.tailscale.operator != null) [
        "--operator"
        "${config.myNixOS.services.tailscale.operator}"
      ];

      openFirewall = true;
      useRoutingFeatures = "both";
    };

    # Decouple tailscaled-autoconnect from multi-user.target entirely so
     # graphical.target (SDDM) can reach active without waiting for
     # `tailscale up` to notify (typically ~5s). Upstream unit has
     # WantedBy=multi-user.target which creates an implicit ordering we
     # couldn't clear by setting before=[] alone. A 3s OnBootSec timer
     # pulls the unit post-boot instead; the tailnet just joins a few
     # seconds later while login is already happening.
    systemd.services.tailscaled-autoconnect = {
      wantedBy = lib.mkForce [ ];
      before = lib.mkForce [ ];
    };

    systemd.timers.tailscaled-autoconnect = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "3s";
        Unit = "tailscaled-autoconnect.service";
      };
    };
  };
}
