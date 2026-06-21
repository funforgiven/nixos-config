{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  greeterPackage = config.programs.noctalia-greeter.package;
in
{
  programs.niri = {
    enable = true;
    useNautilus = true;
  };

  programs.noctalia-greeter = {
    enable = true;
    greeter-args = "--session niri --user ${username}";
    settings.cursor = {
      theme = "Adwaita";
      size = 24;
      package = pkgs.adwaita-icon-theme;
    };
  };

  services.greetd.settings.default_session = {
    user = "greeter";
    command = lib.mkForce (
      "${pkgs.coreutils}/bin/env "
      + "XKB_DEFAULT_LAYOUT=tr "
      + "XCURSOR_THEME=Adwaita "
      + "XCURSOR_SIZE=24 "
      + "XCURSOR_PATH=${pkgs.adwaita-icon-theme}/share/icons "
      + "${greeterPackage}/bin/noctalia-greeter-session -- --session niri --user ${username}"
    );
  };

  services.libinput.enable = true;
  services.accounts-daemon.enable = true;

  services.xserver.xkb = {
    layout = "tr";
    variant = "";
  };

  console = {
    keyMap = "trq";
    useXkbConfig = false;
  };

  xdg = {
    mime.enable = true;
    menus.enable = true;
    autostart.enable = true;
    terminal-exec.enable = true;
    portal = {
      enable = true;
      xdgOpenUsePortal = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gnome
        xdg-desktop-portal-gtk
      ];
      config.common.default = [
        "gnome"
        "gtk"
      ];
    };
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    XDG_CURRENT_DESKTOP = "niri";
    XDG_SESSION_DESKTOP = "niri";
  };

  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    grim
    nautilus
    slurp
    xdg-utils
  ];
}
