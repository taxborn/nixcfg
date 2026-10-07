{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myNixOS.profiles.audio;
in
{
  options.myNixOS.profiles.audio.enable = lib.mkEnableOption "audio support";

  config = lib.mkIf cfg.enable {
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };

    environment.systemPackages = with pkgs; [
      pavucontrol
    ];
  };
}
