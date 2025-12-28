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
    self.nixosModules.locale-en-us
  ];

  networking.hostName = "tungsten";
  time.timeZone = "America/Chicago";
  nixpkgs.hostPlatform = "x86_64-linux";

  myUsers.taxborn = {
    enable = true;
    password = "$y$j9T$23GUNNxavO/S4n8DLkfs71$ShByJUJ9XCvIs2PLYmlAjenOtpcFvnSgshjbClEKB18";
  };
}
