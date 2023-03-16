{ options, config, lib, pkgs, inputs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.gnome;
in
{
  options.modules.desktop.gnome = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # Enable the X11 windowing system.
    services.xserver.enable = true;

    # Enable the Gnome Desktop Environment.
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.desktopManager.gnome.enable = true;

    # Configure keymap in X11
    services.xserver.layout = "tr";

    hardware.pulseaudio.enable = false;
    systemd.services.NetworkManager-wait-online.enable = false;

    environment.systemPackages = with pkgs; [
      gnome.gnome-tweaks
    ];

    services.udev.packages = with pkgs; [ gnome.gnome-settings-daemon ];

    home-manager.users.funforgiven = { pkgs, config, lib, ... }:
      let
        orchis = pkgs.orchis-theme.override {
          tweaks = [ "solid" "compact" "black" "primary" ];
        };
      in
      rec {
        home.packages = with pkgs.gnomeExtensions; [
          user-themes
          vitals
          dash-to-panel
          appindicator
        ];

        dconf.settings = with lib.hm.gvariant; {
          "org/gnome/shell" = {
            disable-user-extensions = false;
            enabled-extensions = map (extension: extension.extensionUuid) home.packages;
            disabled-extensions = [ ];
          };
          "org/gnome/shell/extensions/user-theme" = {
            name = config.gtk.theme.name;
          };
          "org/gnome/shell/extensions/vitals" = {
            hot-sensors = [
              "_processor_usage_"
              "__temperature_max__"
              "_memory_available_"
              "__network-rx_max__"
              "__network-tx_max__"
            ];
            position-in-panel = 0;
          };
          "org/gnome/shell/extensions/dash-to-panel" = {
            "appicon-margin" = 0;
            "appicon-padding" = 6;
            "tray-padding" = 4;
            "click-action" = "TOGGLE-SHOWPREVIEW";
            "dot-position" = "TOP";
            "dot-style-focused" = "METRO";
            "dot-style-unfocused" = "DASHES";
            "group-apps" = true;
            "isolate-workspaces" = true;
            "middle-click-action" = "MINIMIZE";
            "shift-click-action" = "LAUNCH";
            "scroll-icon-action" = "NOTHING";
            "scroll-panel-action" = "NOTHING";
            "stockgs-panelbtn-click-only" = true;
          };
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
            clock-show-weekday = true;
            clock-show-date = true;
            clock-show-seconds = true;
            enable-hot-corners = false;
          };
          "org/gnome/desktop/input-sources" = {
            sources = [ (mkTuple [ "xkb" "tr" ]) ];
          };
          "org/gnome/shell" = {
            favorite-apps = [
              "firefox.desktop"
              "org.gnome.Nautilus.desktop"
              "org.telegram.desktop.desktop"
            ];
          };
        };

        gtk = {
          enable = true;
          theme = {
            name = "Orchis-Green-Dark-Compact";
            package = orchis;
          };

          iconTheme = {
            name = "Papirus-Dark";
            package = pkgs.papirus-icon-theme.override {
              color = "green";
            };
          };

          cursorTheme = {
            name = "Catppuccin-Mocha-Dark-Cursors";
            package = pkgs.catppuccin-cursors.mochaDark;
            size = 32;
          };
        };

        home.file.".config/gtk-4.0/gtk.css".source = "${orchis}/share/themes/Orchis-Green-Dark-Compact/gtk-4.0/gtk.css";
        home.file.".config/gtk-4.0/gtk-dark.css".source = "${orchis}/share/themes/Orchis-Green-Dark-Compact/gtk-4.0/gtk-dark.css";

        home.file.".config/gtk-4.0/assets" = {
          recursive = true;
          source = "${orchis}/share/themes/Orchis-Green-Dark-Compact/gtk-4.0/assets";
        };
      };
  };
}
