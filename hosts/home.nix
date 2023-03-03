{ pkgs, config, lib, ... }:

with builtins;
with lib;
{
  time = {
    timeZone = "Europe/Istanbul";
    hardwareClockInLocalTime = true;
  };

  i18n = {
    defaultLocale = "en_US.UTF-8";

    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "ja_JP.UTF-8/UTF-8"
    ];
  };

  # Networking
  networking.networkmanager.enable = true;

  # Steam controller support
  hardware.steam-hardware.enable = true;

  # Zram
  zramSwap.enable = true;

  # Microcode
  hardware.enableRedistributableFirmware = true;

  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_zen;
    loader.grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      useOSProber = true;
    };
  };
}
