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
      apps.enable = true;
      fonts.enable = true;

      browsers = {
        default = "firefox";
        firefox.enable = true;
      };

      gaming = {
        enable = true;
        steam.enable = true;
      };

      programs = {
        discord.enable = true;
        unity.enable = true;
      };
    };

    editors = {
      rider.enable = true;
    };

    services = {
      tailscale.enable = true;
    };

    hardware = {
      bluetooth.enable = true;
      intel.enable = true;
      nvidia.enable = true;
      pipewire.enable = true;
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
