{
  self,
  pkgs,
  ...
}:
{
  home-manager.users.taxborn = {
    imports = [
      self.homeModules.profile-workstation
    ];

    config = {
      home.packages = with pkgs; [
        ledger-live-desktop
        prismlauncher
        via
      ];
    };
  };
}
