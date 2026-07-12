_: {
  nixos.modules.networking = {
    networking = {
      networkmanager = {
        enable = true;
        dns = "systemd-resolved";
      };
    };

    services.resolved.enable = true;
  };
}
