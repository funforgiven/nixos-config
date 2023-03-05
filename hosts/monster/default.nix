{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../home.nix
    ./hardware-configuration.nix
  ];

  system.stateVersion = "23.05";

  modules = {
    desktop = {
      kde.enable = true;
      fonts.enable = true;

      browsers = {
        firefox.enable = true;
        brave.enable = true;
        default = "firefox";
      };

      gaming = {
        enable = true;
        steam.enable = true;
      };

      programs = {
        enable = true;
        discord.enable = true;
        unity.enable = true;
      };

      term = {
        wezterm.enable = true;
        default = "wezterm";
      };
    };

    editors = {
      helix.enable = true;
      vscode.enable = true;
      rider.enable = true;
      editor = "hx";
      visual = "code";
    };

    services = {
      tailscale.enable = true;
      pipewire.enable = true;
      docker.enable = true;
    };

    hardware = {
      bluetooth.enable = true;
      intel.enable = true;
      nvidia.enable = true;
    };

    shell = {
      zsh.enable = true;
    };
  };

  # Zram
  zramSwap.enable = true;

  # Some battery life tuning
  services.tlp.enable = true;

  # Disable power-profiles-daemon as it conflicts with tlp
  services.power-profiles-daemon.enable = false;

  # Thermal config
  services.thermald.enable = true;

}
