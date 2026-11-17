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
      description = "Open port 22 on every interface. Workstations turn it off.";
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
