_: {
  nixos.modules.parmigiano-hardware =
    { pkgs, ... }:
    {
      hardware.block.scheduler."nvme[0-9]*" = "none";

      boot = {
        kernelPackages = pkgs.linuxPackages_latest;
        initrd.availableKernelModules = [
          "nvme"
          "xhci_pci"
          "usb_storage"
          "usbhid"
          "sd_mod"
        ];
      };
    };
}
