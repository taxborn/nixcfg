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
