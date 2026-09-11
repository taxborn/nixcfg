{ config, lib, ... }:
let
  cfg = config.myHardware.logitech.mx-master;
in
{
  options.myHardware.logitech.mx-master.enable =
    lib.mkEnableOption "MX Master 3S gestures for the workstation keybindings";

  config = lib.mkIf cfg.enable {
    hardware.logitech.wireless.enable = true;
    programs.solaar.enable = true;

    # The MX Master 3S thumb button emits no BTN_* event of its own. It is a
    # HID++ control that Logi Options+ would interpret, so there is nothing
    # for Niri to bind until logid claims it and synthesises keys through
    # uinput. Those combos are bound in the Niri config. Solaar's daemon
    # must stay off; it drives HID++ on the same device and the two conflict.
    services.logiops = {
      enable = true;
      config.devices = [
        {
          name = "MX Master 3S"; # must match the HID++ name solaar reports
          buttons = [
            {
              cid = 195; # 0xc3, the gesture button; nix has no hex literals
              action = {
                type = "Gestures";
                gestures = [
                  {
                    direction = "Left";
                    mode = "OnRelease";
                    action = {
                      type = "Keypress";
                      keys = [
                        "KEY_LEFTMETA"
                        "KEY_LEFTBRACE"
                      ];
                    };
                  }
                  {
                    direction = "Right";
                    mode = "OnRelease";
                    action = {
                      type = "Keypress";
                      keys = [
                        "KEY_LEFTMETA"
                        "KEY_RIGHTBRACE"
                      ];
                    };
                  }
                  {
                    # Pressed without moving; Super+R opens Noctalia's launcher.
                    direction = "None";
                    mode = "OnRelease";
                    action = {
                      type = "Keypress";
                      keys = [
                        "KEY_LEFTMETA"
                        "KEY_R"
                      ];
                    };
                  }
                ];
              };
            }
          ];
        }
      ];
    };
  };
}
