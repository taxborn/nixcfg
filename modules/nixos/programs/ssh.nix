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
        # The forwarded socket lands on a path something else may already own:
        # this host's own gpg-agent on a workstation, or a socket left behind
        # by a session that died without cleaning up. sshd's default is to
        # refuse the bind in that case, so every reconnect after a hard
        # disconnect would come up without a card until someone removed the
        # file by hand.
        StreamLocalBindUnlink = true;
      };
    };

    networking.firewall.allowedTCPPorts = [ 22 ];

    # sshd binds the forwarded gpg socket inside this directory and will not
    # create it, so on a host with no local gpg-agent nothing else does either
    # and the forward fails with `bind: No such file or directory`.
    #
    # Lingering is what makes this reliable rather than lucky. The rules run
    # from the user's systemd manager, and without lingering that manager is
    # started by the very SSH login that needs the directory — a race sshd
    # loses about as often as it wins. With it, the manager comes up at boot
    # and the directory is there before the first connection.
    users.users.taxborn.linger = true;
    systemd.user.tmpfiles.users.taxborn.rules = [
      "d ${gnupgSocketDir} 0700 - - -"
    ];
  };
}
