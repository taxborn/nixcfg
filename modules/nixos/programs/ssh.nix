{
  config,
  lib,
  ...
}:
let
  cfg = config.myNixOS.programs.ssh;
in
{
  options.myNixOS.programs.ssh.enable = lib.mkEnableOption "sshd and known hosts";

  config = lib.mkIf cfg.enable {
    programs.ssh.knownHosts = config.mySnippets.ssh.knownHosts;

    networking.firewall.allowedTCPPorts = [ 22 ];
  };
}
