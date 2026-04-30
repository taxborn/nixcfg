{
  self,
  modulesPath,
  ...
}:
{
  imports = [
    ./home.nix
    ./networking.nix
    ./secrets.nix

    self.diskoConfigurations.btrfs-carbon
    self.nixosModules.locale-en-us

    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  networking.hostName = "carbon";
  time.timeZone = "America/Chicago";
  system.stateVersion = "25.11";

  myNixOS.profiles.ovhServer.enable = true;

  myUsers.taxborn = {
    enable = true;
    password = "$y$j9T$23GUNNxavO/S4n8DLkfs71$ShByJUJ9XCvIs2PLYmlAjenOtpcFvnSgshjbClEKB18";
  };
}
