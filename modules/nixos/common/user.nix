{
  config,
  pkgs,
  self,
  ...
}:

{
  programs.fish.enable = true;

  age.secrets.taxbornPassword.file = "${self}/secrets/users/taxborn-password.age";

  users = {
    users.taxborn = {
      description = "Braxton";
      uid = 1000;
      isNormalUser = true;
      # `mutableUsers = false` below, so `passwd` does not survive a rebuild
      # and the hash has to be declared to exist at all. It lives in an agenix
      # secret because this repo is pushed to a public knot, and the hash is the
      # sudo password on every host. agenix orders its decryption before the
      # `users` activation script, so the file exists when accounts are created.
      # If it were ever missing the account would have no password and `sudo`
      # would lock out, so keep a root session open while switching.
      hashedPasswordFile = config.age.secrets.taxbornPassword.path;
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
