{ config, lib, pkgs, modulesPath, ... }:
{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usbhid" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/2b2d796d-69b2-496b-911b-3f1b5a1600f6";
      fsType = "btrfs";
      options = [ "subvol=root" "compress-force=zstd" "discard=async" ];
    };

  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/2b2d796d-69b2-496b-911b-3f1b5a1600f6";
      fsType = "btrfs";
      options = [ "subvol=nix" "compress-force=zstd" "discard=async" "noatime" ];
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/2b2d796d-69b2-496b-911b-3f1b5a1600f6";
      fsType = "btrfs";
      options = [ "subvol=home" "compress-force=zstd" "discard=async" ];
    };

  fileSystems."/hdd" =
    { device = "/dev/disk/by-uuid/f48e7337-2f24-4ad1-a0b4-41ab78140bd8";
      fsType = "btrfs";
      options = [ "compress-force=zstd" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/7AD0-1C56";
      fsType = "vfat";
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/cff0c8b2-865d-4b41-872a-68ba2886f424"; }
    ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp3s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp4s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
