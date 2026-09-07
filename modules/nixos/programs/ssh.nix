{
  config,
  lib,
  ...
}:
let
  cfg = config.myNixOS.programs.ssh;
in
{
  options.myNixOS.programs.ssh.enable = lib.mkEnableOption ''
    known-host pins and the firewall opening for sshd.

    sshd itself comes from `myNixOS.base`
  '';

  config = lib.mkIf cfg.enable {
    programs.ssh.knownHosts = config.mySnippets.ssh.knownHosts;

    networking.firewall.allowedTCPPorts = [ 22 ];
  };
}
