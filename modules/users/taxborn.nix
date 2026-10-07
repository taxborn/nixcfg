{ pkgs, self, ... }:

{
  programs.fish.enable = true;

  users = {
    users.taxborn = {
      description = "Braxton";
      uid = 1000;
      isNormalUser = true;
      # `mutableUsers = false` below, so `passwd` does not survive a rebuild
      # and the hash has to be declared here to exist at all.
      hashedPassword = "$y$j9T$A0TNjHtgoYuPaVVUDMTg1/$c2X6a5BbYruE.WN0ko5uE3O.FTGDFeEWjFDxwL4YS28";
      extraGroups = [
        "networkmanager"
        "video"
        "wheel"
      ];
      openssh.authorizedKeys.keyFiles = [
        "${self}/keys/yubikey.pub"
      ];
    };
    defaultUserShell = pkgs.fish;
    mutableUsers = false;
  };

  # The user module owns this rather than the service module naming a person.
  myNixOS.services.tailscale.operator = "taxborn";
}
