{
  self,
  ...
}:
{
  home-manager.users.taxborn = {
    imports = [
      self.homeModules.profile-workstation
    ];

    config = {
      myHome = {
        programs = {
          obs.enable = true;
          ledger.enable = true;
          minecraft.enable = true;
          via.enable = true;
        };
        services.hypridle.autoSuspend = false;
      };

      home.file.".curlrc".text = ''
        ipv4
        retry 5
        retry-delay 5
        retry-connrefused
      '';
    };
  };
}
