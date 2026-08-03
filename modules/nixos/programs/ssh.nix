{
  config,
  lib,
  ...
}:
let
  cfg = config.myNixOS.programs.ssh;
  inherit (config.mySnippets.ssh) gnupgSocketDir;
in
{
  options.myNixOS.programs.ssh.enable = lib.mkEnableOption "sshd, known hosts, and agent forwarding";

  config = lib.mkIf cfg.enable {
    programs.ssh.knownHosts = config.mySnippets.ssh.knownHosts;

    services.openssh = {
      # 22 stays for Tailscale SSH to answer on the tailnet; sshd also listens
      # on `mySnippets.ssh.port`, which is the one the client config addresses
      # and the only one where socket forwarding works. See the option.
      #
      # `openFirewall` would punch a hole for every listed port on every
      # interface, which would put the forwarding port on Argon's and Carbon's
      # public addresses. It is off, 22 is opened by hand below, and the
      # forwarding port stays reachable over the tailnet only because the
      # tailscale interface is in `trustedInterfaces`.
      ports = [
        22
        config.mySnippets.ssh.port
      ];
      openFirewall = false;

      settings = {
        StreamLocalBindUnlink = true;
      };
    };

    networking.firewall.allowedTCPPorts = [ 22 ];

    users.users.taxborn.linger = true;
    systemd.user.tmpfiles.users.taxborn.rules = [
      "d ${gnupgSocketDir} 0700 - - -"
    ];
  };
}
