_: {
  home.gui =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      assertions = [
        {
          assertion = config.stylix.image != null;
          message = "The Niri wallpaper service requires a declared Stylix image.";
        }
      ];

      systemd.user.services.swaybg = {
        Unit = {
          Description = "Declarative Niri wallpaper";
          Documentation = "man:swaybg(1)";
          ConditionEnvironment = "WAYLAND_DISPLAY";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
          Requisite = [ "graphical-session.target" ];
          X-Restart-Triggers = [ "${config.stylix.image}" ];
        };

        Service = {
          ExecStart = lib.escapeShellArgs [
            (lib.getExe pkgs.swaybg)
            "--image"
            "${config.stylix.image}"
            "--mode"
            config.stylix.imageScalingMode
          ];
          Restart = "on-failure";
          RestartSec = 1;
          Slice = "background-graphical.slice";
          TimeoutStopSec = "10s";
        };

        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
