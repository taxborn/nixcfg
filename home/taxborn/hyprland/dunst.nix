{ pkgs, ... }:

{
  services.dunst = {
    enable = true;

    iconTheme = {
      name = "Papirus";
      package = pkgs.papirus-icon-theme;
    };

    settings = {
      global = {
        follow = "keyboard";
        width = 370;
        separator_height = 1;
        padding = 8;
        horizontal_padding = 8;
        frame_width = 1;
        sort = "update";
        idle_threshold = 120;
        alignment = "center";
        word_wrap = "yes";
        transparency = 5;
      };
    };
  };
}
