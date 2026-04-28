{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myHome.programs.ssh.enable = lib.mkEnableOption "openssh client";

  config = lib.mkIf config.myHome.programs.ssh.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      matchBlocks =
        let
          tailscaleIPs = config.mySnippets.mischief-town.networkMap.tailscaleIPs;

          machine = name: ip: {
            ${name} = {
              hostname = ip;
              user = "taxborn";
              extraOptions = {
                RequestTTY = "yes";
                RemoteCommand = "tmux new -As0";
              };
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
            hostname = "de4388.rsync.net";
            user = "de4388";
          };

          "*" = {
            forwardAgent = false;
            addKeysToAgent = "no";
            compression = false;
            serverAliveInterval = 0;
            serverAliveCountMax = 3;
            hashKnownHosts = false;
            userKnownHostsFile = "~/.ssh/known_hosts";
            controlMaster = "no";
            controlPath = "~/.ssh/master-%r@%n:%p";
            controlPersist = "no";
          };
        };

      package = pkgs.openssh;
    };
  };
}
