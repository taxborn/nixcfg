{ pkgs, ... }:

{
  imports = [
    ../common
    ./caddy.nix

    ./hardware-configuration.nix
    ./disks.nix
    ./backup.nix
  ];

  networking.hostName = "carbon";
  time.timeZone = "America/Chicago";

  environment.systemPackages = with pkgs; [
    jdk21_headless
    forgejo-actions-runner
  ];
  networking.firewall.allowedTCPPorts = [
    25565
    25566
  ];

  services.openssh.extraConfig = "StreamLocalBindUnlink yes";

  system.stateVersion = "25.05";
}
