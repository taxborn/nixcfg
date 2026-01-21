{
  pkgs,
  self,
  ...
}:
{
  home-manager.users.taxborn = {
    imports = [
      self.homeModules.taxborn
    ];

    config = {
      home = {
        packages = with pkgs; [
          discord
          obsidian
          spotify
        ];
      };

      programs = {
        zen-browser = {
          enable = true;
          nativeMessagingHosts = [ pkgs.bitwarden-desktop ];
        };
      };

      myHome = {
        taxborn.programs = {
          minecraft.enable = true;
          zed-editor.enable = true;
        };
        profiles.defaultApps.enable = true;
        desktop.hyprland.enable = true;
        programs = {
          ghostty.enable = true;
          obs.enable = true;
        };
      };
    };
  };
}
