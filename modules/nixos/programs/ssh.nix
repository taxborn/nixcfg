{
  config,
  lib,
  ...
}:
let
  cfg = config.myNixOS.programs.ssh;
in
{
  options.myNixOS.programs.ssh = {
    enable = lib.mkEnableOption ''
      known-host pins and the firewall opening for sshd.

      sshd itself comes from `myNixOS.base`
    '';

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Open port 22 to every interface. Servers keep this on. Carbon takes
        the site's deploy key on its public address, and the other two want a
        way in when tailscaled is down.

        `profiles.workstation` turns it off. A workstation runs no fail2ban,
        and the laptop joins networks nobody here controls. Closing the port
        costs nothing on the tailnet, where `tailscale0` is a trusted
        interface and Tailscale SSH answers 22 without sshd. The way in when
        the tailnet is down is the keyboard.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.ssh.knownHosts = config.mySnippets.ssh.knownHosts;

    # Both halves follow the option. nixpkgs opens 22 by itself through
    # `services.openssh.openFirewall`, which defaults to true, so leaving that
    # alone would keep the port open whatever this module said. `mkDefault`
    # because the backup server sets it false for a different reason, see
    # `services/backups`, and still wants 22 open through the line below.
    services.openssh.openFirewall = lib.mkDefault cfg.openFirewall;

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ 22 ];
  };
}
