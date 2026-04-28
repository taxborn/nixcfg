{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myHome.programs.yubikey.enable = lib.mkEnableOption "yubikey";

  config = lib.mkIf config.myHome.programs.yubikey.enable {
    home.packages = [ pkgs.yubikey-manager ];

    xdg.configFile."age/yubikey-identity.txt".text = ''
      #       Serial: 33852487, Slot: 1
      #         Name: age
      #      Created: Tue, 28 Apr 2026 13:24:27 +0000
      #   PIN policy: Once   (A PIN is required once per session, if set)
      # Touch policy: Cached (A physical touch is required for decryption, and is cached for 15 seconds)
      #    Recipient: age1yubikey1q0kr3jdz8lu2pzv6hery4rfpq7jf94kccmltlm27093sjac9yqcx7lak4cu
      AGE-PLUGIN-YUBIKEY-1G7XQGQ5ZZ7VW98CMVZEPX
    '';
  };
}
