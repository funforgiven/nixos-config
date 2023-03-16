{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../home.nix
    ./hardware-configuration.nix
  ];

  system.stateVersion = "23.05";

  modules = {
    desktop = {
      gnome.enable = true;
      fonts.enable = true;

      browsers = {
        firefox.enable = true;
        brave.enable = true;
        edge.enable = true;
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
        kitty.enable = true;
      };
    };

    editors = {
      helix.enable = true;
      vscode.enable = true;
      rider.enable = true;
      editor = "hx";
      visual = "code --wait";
    };

    services = {
      tailscale.enable = true;
      pipewire.enable = true;
      docker.enable = true;
      onepassword.enable = true;
    };

    hardware = {
      bluetooth.enable = true;
      intel.enable = true;
      nvidia.enable = true;
    };

    shell = {
      zsh.enable = true;
      starship.enable = true;
    };
  };

  # Zram
  zramSwap.enable = true;

  # Thermal config
  services.thermald.enable = true;
}
