{
  config,
  lib,
  ...
}:
{
  options.myHome.taxborn.programs.zed-editor.enable = lib.mkEnableOption "zed editor";

  config = lib.mkIf config.myHome.taxborn.programs.zed-editor.enable {
    programs.zed-editor = {
      enable = true;
      installRemoteServer = true;

      userKeymaps = [
        {
          context = "Workspace";

          bindings = {
            cmd-p = "command_palette::Toggle";
            cmd-shift-p = "file_finder::Toggle";
            ctrl-p = "command_palette::Toggle";
            ctrl-shift-p = "file_finder::Toggle";
          };
        }
      ];

      userSettings = {
        auto_indent_on_paste = true;
        auto_update = false;
        autosave.after_delay.milliseconds = 1000;

        features.edit_prediction_provider = "copilot";
        minimap.show = "auto";
        preferred_line_length = 80;
        soft_wrap = "preferred_line_length";

        use_on_type_format = true;
        wrap_guides = [ 80 ];
      };
    };
  };
}
