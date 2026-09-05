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
      description = ''
        Auth key tailscaled logs in with, held in a file so it can come from
        agenix. Defaults to the secret this module declares.

        Null is a build failure, by the assertion below, rather than a host
        that quietly comes up unjoined. Off the tailnet it has no route to the
        backup server and no Tailscale SSH to be fixed over.
      '';
      default = config.age.secrets.tailscaleAuthKey.path or null;
      type = lib.types.nullOr lib.types.path;
    };

    operator = lib.mkOption {
      description = ''
        Unix user handed control of tailscaled, so `tailscale status` and the
        rest of the CLI work without sudo. Null leaves them root-only.
      '';
      default = "taxborn";
      type = lib.types.nullOr lib.types.str;
    };
  };

  config = lib.mkIf config.myNixOS.services.tailscale.enable {
    assertions = [
      {
        assertion = config.myNixOS.services.tailscale.authKeyFile != null;
        message = "myNixOS.services.tailscale.authKeyFile cannot be null.";
      }
    ];

    age.secrets.tailscaleAuthKey.file = "${self}/secrets/tailscale/auth.age";

    # A trusted interface is accepted before the port rules are reached, which
    # is what makes every loopback-bound service here reachable over the
    # tailnet without opening a port for it. One exception is worth
    # remembering. fail2ban hooks its chains on ahead of that accept, so its
    # ignoreIP, not this line, is what keeps a ban off the tailnet.
    # Only the trusted interface here. The UDP port is `openFirewall` below,
    # which sets this same list to this same value.
    networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];

    services.tailscale = {
      enable = true;
      inherit (config.myNixOS.services.tailscale) authKeyFile;

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
      extraUpFlags = lib.optionals (config.myNixOS.services.tailscale.operator != null) [
        "--operator"
        "${config.myNixOS.services.tailscale.operator}"
      ];

      openFirewall = true;
      useRoutingFeatures = "both";
    };
  };
}
