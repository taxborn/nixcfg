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

      settings =
        let
          tailscaleIPs = config.mySnippets.tailnet.tailscaleIPs;

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

          forgejo = {
            Hostname = "git.mischief.town";
            Port = 2222;
            User = "git";
            # TODO: seems like I can only access over ipv4, see if I can fix that
            AddressFamily = "inet";
          };

          "*" = {
            ForwardAgent = "no";
            AddKeysToAgent = "no";
            Compression = "no";
            ServerAliveInterval = 0;
            ServerAliveCountMax = 3;
            HashKnownHosts = "no";
            UserKnownHostsFile = "~/.ssh/known_hosts";
            ControlMaster = "no";
            ControlPath = "~/.ssh/master-%r@%n:%p";
            ControlPersist = "no";
          };
        };

      package = pkgs.openssh;
    };
  };
}
