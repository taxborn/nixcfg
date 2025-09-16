# Note on Secure Boot:
# If installing NixOS on a new machine, you can't (*) start
# with secure boot. You need to first boot with `systemd-boot`
# and then switch to lanzaboote.
#
# (*) It seems like there is a way if I package certain keys
#     with the install ISO. Not something I want to do right
#     now but something I can look into in the future, I like
#     re-installing.

{
  inputs,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    inputs.lanzaboote.nixosModules.lanzaboote
  ];

  # doesn't have too much of a use after initial install,
  # but might be good to keep around.
  environment.systemPackages = with pkgs; [
    sbctl
  ];

  boot = {
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };

    # lanzaboote replaces systemd-boot.
    loader.systemd-boot.enable = lib.mkForce false;
  };
}
