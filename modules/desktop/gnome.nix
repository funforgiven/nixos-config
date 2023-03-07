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
    hardware.pulseaudio.enable = false;

    # Enable the KDE Plasma Desktop Environment.
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.desktopManager.gnome.enable = true;

    # Configure keymap in X11
    services.xserver = {
      layout = "tr";
    };

    systemd.services.NetworkManager-wait-online.enable = false;

    environment.systemPackages = with pkgs; [
      gnome.gnome-tweaks
      gnome-themes-extra
      gtk-engine-murrine
    ];

    home-manager.users.funforgiven = { pkgs, config, lib, ... }: rec {

      home.packages = with pkgs.gnomeExtensions; [
        user-themes
        improved-workspace-indicator
        vitals
        blur-my-shell
        dash-to-panel
      ];

      dconf.settings = with lib.hm.gvariant; {
        "org/gnome/shell" = {
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
        "org/gnome/shell/extensions/improved-workspace-indicator" = {
          panel-position = "right";
        };
        "org/gnome/shell/extensions/dash-to-panel" = {
          "appicon-margin" = 0;
          "appicon-padding" = 6;
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
          name = "Catppuccin-Mocha-Standard-Sky-Dark";
          package = pkgs.catppuccin-gtk.override {
            accents = [ "sky" ];
            variant = "mocha";
          };
        };
        iconTheme = {
          name = "Papirus-Dark";
          package = pkgs.papirus-icon-theme;
        };
        cursorTheme = {
          name = "Catppuccin-Mocha-Dark-Cursors";
          package = pkgs.catppuccin-cursors.mochaDark;
          size = 32;
        };
      };
    };
  };
}
