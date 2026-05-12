{
  self,
  modulesPath,
  pkgs,
  ...
}:
{
  imports = [
    ./home.nix
    ./proxy.nix
    ./secrets.nix

    self.diskoConfigurations.btrfs-carbon
    self.nixosModules.locale-en-us

    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  networking = {
    hostName = "carbon";
    firewall.allowedTCPPorts = [ 25565 ];
  };
  time.timeZone = "America/Chicago";
  system.stateVersion = "25.11";

  environment.systemPackages = [ pkgs.jdk17 ];

  myNixOS = {
    services = {
      vaultwarden.enable = true;
      pds.enable = true;
      monitoring.client.enable = true;
      forgejo.enable = true;
    };
    profiles.ovhServer.enable = true;
  };
}
