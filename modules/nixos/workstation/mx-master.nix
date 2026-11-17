{
  hardware.logitech.wireless.enable = true;
  programs.solaar.enable = true;

  # Solaar's userService must stay off. It fights logiops over HID++.
  services.logiops = {
    enable = true;
    config.devices = [
      {
        name = "MX Master 3S";
        buttons = [
          {
            cid = 195;
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
}
