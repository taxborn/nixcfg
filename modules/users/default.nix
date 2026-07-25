{ pkgs, ... }:

{
  programs.fish.enable = true;

  users = {
    users.taxborn = {
      description = "Braxton";
      uid = 1000;
      isNormalUser = true;
      hashedPassword = "$y$j9T$A0TNjHtgoYuPaVVUDMTg1/$c2X6a5BbYruE.WN0ko5uE3O.FTGDFeEWjFDxwL4YS28";
      extraGroups = [
        "wheel"
      ];
      openssh.authorizedKeys.keyFiles = [
        ../../secrets/publicKeys/yubikey.pub
      ];
    };
    defaultUserShell = pkgs.fish;
    mutableUsers = false;
  };
}
