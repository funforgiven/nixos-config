_: {
  nixos.modules.amd-desktop = {
    hardware.cpu.amd.updateMicrocode = true;

    boot = {
      kernelModules = [ "kvm-amd" ];
      kernelParams = [ "amd_pstate=active" ];
    };
  };
}
