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
        show = "drun";
        prompt = "Search...";
        allow_images = true;
        gtk_dark = true;
        insensitive = true;
        location = "center";
        width = 600;
        height = 350;
      };
      style = ''
        * {
          font-family: "JetBrainsMonoNL NFM", monospace;
          font-size: 16px;
        }

        window {
          background-color: transparent;
          color: #cdd6f4;
          margin: 0px;
          padding: 20px;
          opacity: 0.95;
        }

        #input {
          margin: 0px 0px 10px 0px;
          padding: 10px;
          border: none;
          background-color: #1e1e2e;
          color: #cdd6f4;
          border-radius: 10px;
          border: 2px solid #cba6f7;
        }

        #input:focus {
          background-color: #313244;
          color: #cdd6f4;
          outline: none;
          box-shadow: none;
        }

        #scroll {
          border: 2px solid #cba6f7;
          background-color: #1e1e2e;
          border-radius: 10px;
        }

        #entry {
          padding: 5px;
        }

        #entry:selected {
          background-color: #313244;
          outline: none;
          border: none;
          border-radius: 10px;
        }
      '';
    };
  };
}
