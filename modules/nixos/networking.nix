{
  networking = {
    networkmanager = {
      enable = true;
      dns = "systemd-resolved";
    };
    firewall.enable = true;
  };

  services.resolved.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.blueman.enable = true;
}
