{
  config,
  lib,
  ...
}:
{
  options.myHome.programs.ssh.enable = lib.mkEnableOption "openssh user configuration";

  config = lib.mkIf config.myHome.programs.ssh.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      settings =
        let
          tailscaleIPs = config.mySnippets.tailnet.tailscaleIPs;
          inherit (config.mySnippets.biscuits-at.networkMap) forgejo;

          # One entry per host in the fleet roster, addressed by tailnet IP
          # rather than by name. `tmux new -As0` attaches session 0 or creates
          # it, so a dropped link leaves the work running and reconnecting
          # lands back in it. The cost is that RemoteCommand takes the slot a
          # command would use: `ssh helium uptime` refuses to run, and a
          # one-shot needs `ssh -o RemoteCommand=none`.
          machine = name: ip: {
            ${name} = {
              Hostname = ip;
              User = "taxborn";
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
            Hostname = "de4388.rsync.net";
            User = "de4388";
          };

          # `git clone forgejo:owner/repo`
          forgejo = {
            Hostname = forgejo.sshDomain;
            User = "git";
            Port = forgejo.sshPort;
          };
        };
    };
  };
}
