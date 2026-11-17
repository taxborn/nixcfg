{
  pkgs,
  config,
  ...
}:
{
  services.getty = {
    autologinOnce = true;
    autologinUser = config.homelab.owner.username;
  };

  boot = {
    consoleLogLevel = 0;

    kernelParams = [
      "quiet"
      "splash"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
      "logo.nologo"
      "vt.global_cursor_default=0"
      "fbcon=nodefer"
    ];

    loader.timeout = 0;

    plymouth = {
      enable = true;
      font = "${pkgs.jetbrains-mono}/share/fonts/truetype/JetBrainsMono-Regular.ttf";
    };
  };
}
