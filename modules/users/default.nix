{ pkgs, ... }:
{
  programs.fish.enable = true;
  documentation.man.cache.enable = false;

  users = {
    users.taxborn = {
      description = "Braxton Fair";
      extraGroups = [
        "docker"
        "libvirtd"
        "networkmanager"
        "video"
        "wheel"
      ];
      hashedPassword = "$y$j9T$A0TNjHtgoYuPaVVUDMTg1/$c2X6a5BbYruE.WN0ko5uE3O.FTGDFeEWjFDxwL4YS28";
      isNormalUser = true;
      uid = 1000;
    };
    defaultUserShell = pkgs.fish;
    mutableUsers = false;
  };
}
