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
          inherit (config.mySnippets.ssh) gnupgSocketDir;

          machine = name: ip: {
            ${name} = {
              Hostname = ip;
              User = "taxborn";
              # Not 22: that is Tailscale SSH, which cannot carry the socket
              # forward below. See `mySnippets.ssh.port`.
              Port = config.mySnippets.ssh.port;
              RequestTTY = "yes";
              RemoteCommand = "tmux new -As0";
              ForwardAgent = true;
              RemoteForward = "${gnupgSocketDir}/S.gpg-agent ${gnupgSocketDir}/S.gpg-agent.extra";
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
        };
    };
  };
}
