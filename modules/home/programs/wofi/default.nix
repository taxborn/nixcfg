{
  config,
  lib,
  ...
}:
{
  options.myHome.programs.wofi.enable = lib.mkEnableOption "wofi application launcher";

  config = lib.mkIf config.myHome.programs.wofi.enable {
    programs.wofi = {
      enable = true;
      settings = {
        allow_images = true;
        width = 600;
        height = 400;
        location = "center";
        show = "drun";
        prompt = "Run";
        insensitive = true;
        hide_scroll = true;
      };
      style = ''
        window {
          background-color: #1e1e2e;
          color: #cdd6f4;
          border-radius: 8px;
          font-family: "JetBrainsMono Nerd Font", monospace;
          font-size: 13px;
        }
        #input {
          margin: 8px;
          padding: 8px;
          background-color: #313244;
          color: #cdd6f4;
          border: none;
          border-radius: 6px;
        }
        #inner-box, #outer-box {
          background-color: #1e1e2e;
        }
        #entry:selected {
          background-color: #45475a;
          border-radius: 6px;
        }
      '';
    };
  };
}
