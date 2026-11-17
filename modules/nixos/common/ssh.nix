{
  config,
  lib,
  self,
  ...
}:
let
  cfg = config.homelab.ssh;
in
{
  options.homelab.ssh = {
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Open port 22 to every interface. Servers keep this on. Carbon takes
        the site's deploy key on its public address, and the other two want a
        way in when tailscaled is down.

        `modules/nixos/workstation` turns it off. A workstation runs no fail2ban,
        and the laptop joins networks nobody here controls. Closing the port
        costs nothing on the tailnet, where `tailscale0` is a trusted
        interface and Tailscale SSH answers 22 without sshd. The way in when
        the tailnet is down is the keyboard.
      '';
    };
  };

  config = {
    programs.ssh.knownHosts = lib.mapAttrs (host: ip: {
      hostNames = [
        host
        "${host}.${config.homelab.tailnet.name}"
        ip
      ];
      publicKeyFile = "${self}/keys/root_${host}.pub";
    }) config.homelab.hosts;

    # nixpkgs opens 22 on its own, so both halves follow the option. mkDefault lets the backup server override it.
    services.openssh.openFirewall = lib.mkDefault cfg.openFirewall;

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ 22 ];
  };
}
