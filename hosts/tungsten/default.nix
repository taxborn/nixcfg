{
  config,
  self,
  ...
}:
{
  imports = [
    ./home.nix
    self.nixosModules.locale-en-us
  ];

  networking.hostname = "tungsten";
  time.timeZone = "America/Chicago";
}
