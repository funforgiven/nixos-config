_: {
  nixos.modules.gpu = {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
  };
}
