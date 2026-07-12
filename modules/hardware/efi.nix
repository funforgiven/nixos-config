_: {
  nixos.modules.efi = {
    boot.loader = {
      timeout = 3;

      efi.canTouchEfiVariables = true;

      systemd-boot = {
        enable = true;
        configurationLimit = 20;
      };
    };
  };
}
