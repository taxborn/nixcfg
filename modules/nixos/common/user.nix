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
    users.${config.homelab.owner.username} = {
      description = config.homelab.owner.name;
      uid = 1000;
      isNormalUser = true;
      # mutableUsers is false. If this file is missing sudo locks out, so keep a root shell open.
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
}
