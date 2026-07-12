_: {
  nixos.modules.firmware = {
    hardware.enableRedistributableFirmware = true;
    services.fwupd.enable = true;
  };
}
