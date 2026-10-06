{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.myNixOS.profiles.graphical-boot.enable = lib.mkEnableOption "non-text boot experience";

  config = lib.mkIf config.myNixOS.profiles.graphical-boot.enable {
    # `autologinOnce` rather than plain autologin. tty1 logs in once per boot,
    # which is all the fish login hook in `profiles/workstation.nix` needs to
    # start Niri. Logging out after that lands on a password prompt rather
    # than another free shell.
    services.getty = {
      autologinOnce = true;
      autologinUser = "taxborn";
    };

    boot = {
      consoleLogLevel = 0;
      initrd.verbose = false;

      kernelParams = [
        "quiet"
        "splash"
        "boot.shell_on_fail"
        "udev.log_priority=3"
        "rd.systemd.show_status=auto"
        # Without these the penguin logo, a blinking text cursor, and a framebuffer
        # console that takes the screen back from Plymouth all show up between
        # the splash and the compositor.
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
  };
}
