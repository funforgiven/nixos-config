{
  boot = {
    initrd.systemd.enable = true;

    loader = {
      timeout = 3;
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 20;
      };
    };

    tmp.cleanOnBoot = true;
  };
}
