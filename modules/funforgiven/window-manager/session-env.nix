_:
let
  waylandEnvironment = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };
in
{
  nixos.modules.session-env = {
    environment.sessionVariables = waylandEnvironment // {
      XDG_SESSION_TYPE = "wayland";
    };
  };

  home.gui.programs.niri.settings.environment = waylandEnvironment;
}
