{
  config,
  lib,
  self,
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

    operator = lib.mkOption {
      description = "Tailscale operator name";
      default = "taxborn";
      type = lib.types.nullOr lib.types.str;
    };

    enableSSH = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Serve SSH over Tailscale, authenticating by tailnet identity.

        Convenient, and it costs more than it looks like. `tailscaled` takes
        port 22 on the tailnet address and answers it itself, so on that path
        sshd is not involved at all: `authorized_keys` is never read and
        `sshd_config` never consulted. Anything that relies on either is
        silently inert over the tailnet — forced commands, `PermitRootLogin`,
        `Match` blocks. `ssh -v` reports `Authenticated ... using "none"`.

        Turn this off on hosts where a forced command is a security boundary
        rather than a convenience. Doing so means that host is reachable only
        with a real SSH key, so make sure one works there first.
      '';
    };
  };

  config = lib.mkIf config.myNixOS.services.tailscale.enable {
    assertions = [
      {
        assertion = config.myNixOS.services.tailscale.authKeyFile != null;
        message = "config.tailscale.authKeyFile cannot be null.";
      }
    ];

    age.secrets.tailscaleAuthKey.file = "${self}/secrets/tailscale/auth.age";

    networking.firewall = {
      allowedUDPPorts = [ config.services.tailscale.port ];
      trustedInterfaces = [ config.services.tailscale.interfaceName ];
    };

    services.tailscale = {
      enable = true;
      inherit (config.myNixOS.services.tailscale) authKeyFile;

      # `tailscale set`, not `tailscale up`. The autoconnect unit only runs `up`
      # when the backend reports NeedsLogin/NeedsMachineAuth/Stopped — on a node
      # that is already Running it notifies ready and exits, so a flag changed
      # in `extraUpFlags` never reaches a machine that is already on the
      # tailnet. The setting would read one way in this file and behave the
      # other way on the host, indefinitely. `tailscaled-set` runs on every
      # activation, so this is the half that actually binds.
      extraSetFlags = [
        "--ssh=${lib.boolToString config.myNixOS.services.tailscale.enableSSH}"
      ];

      # NOTE: `--operator` has the same latent problem — it is only applied on
      # first join. It has never changed, so it has never mattered; move it here
      # too if it ever does.
      extraUpFlags = lib.optionals (config.myNixOS.services.tailscale.operator != null) [
        "--operator"
        "${config.myNixOS.services.tailscale.operator}"
      ];

      openFirewall = true;
      useRoutingFeatures = "both";
    };
  };
}
