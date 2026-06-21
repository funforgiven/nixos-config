{
  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    validateConfig = true;

    settings = {
      shell = {
        niri_overview_type_to_launch_enabled = true;
        polkit_agent = true;
        telemetry_enabled = false;
        time_format = "{:%H:%M}";
        date_format = "%A, %x";
      };

      theme = {
        mode = "dark";
        source = "builtin";
        builtin = "Noctalia";
      };

      wallpaper = {
        enabled = true;
        directory = "~/Pictures/Wallpapers";
        default.path = "";
      };

      backdrop.enabled = true;

      weather.enabled = false;
      dock.enabled = false;
    };
  };
}
