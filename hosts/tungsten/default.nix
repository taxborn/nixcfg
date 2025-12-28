{
  config,
  self,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./home.nix
    self.diskoConfigurations.luks-btrfs-tungsten
    self.nixosModules.locale-en-us
  ];

  networking.hostName = "tungsten";
  time.timeZone = "America/Chicago";
  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "25.11";

  myNixOS = {
    base.enable = true;
    programs = {
      lanzaboote.enable = true;
    };
  };

  myUsers.taxborn = {
    enable = true;
    password = "$y$j9T$23GUNNxavO/S4n8DLkfs71$ShByJUJ9XCvIs2PLYmlAjenOtpcFvnSgshjbClEKB18";
  };
}
