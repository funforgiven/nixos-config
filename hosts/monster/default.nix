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
        default = "firefox";
      };

      gaming = {
        enable = true;
        steam.enable = true;
      };

      programs = {
        essentials.enable = true;
        discord.enable = true;
        unity.enable = true;
        rider.enable = true;
      };
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

  # Some battery life tuning
  services.tlp.enable = true;

  # Disable power-profiles-daemon as it conflicts with tlp
  services.power-profiles-daemon.enable = false;

  # Thermal config
  services.thermald.enable = true;
}
