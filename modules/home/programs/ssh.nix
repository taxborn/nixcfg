{
  lib,
  osConfig,
  ...
}:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings =
      let
        tailscaleIPs = osConfig.homelab.hosts;
        inherit (osConfig.homelab.services) knot;

        machine = name: ip: {
          ${name} = {
            Hostname = ip;
            User = osConfig.homelab.owner.username;
            RequestTTY = "yes";
            RemoteCommand = "tmux new -As0";
          };
        };

        machines = lib.foldlAttrs (
          acc: name: ip:
          acc // machine name ip
        ) { } tailscaleIPs;
      in
      machines
      // {
        rsync-backup = {
          Hostname = osConfig.homelab.rsyncNet.host;
          User = osConfig.homelab.rsyncNet.user;
        };

        ${knot.domain} = {
          Hostname = knot.sshDomain;
          User = "git";
          Port = knot.sshPort;
        };
        tangled = {
          Hostname = knot.sshDomain;
          User = "git";
          Port = knot.sshPort;
        };
      };
  };
}
