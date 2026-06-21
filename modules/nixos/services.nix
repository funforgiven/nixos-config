{
  security.polkit.enable = true;

  services = {
    upower.enable = true;
    power-profiles-daemon.enable = true;
    udisks2.enable = true;
    fwupd.enable = true;
    dbus.enable = true;
    avahi = {
      enable = true;
      nssmdns4 = true;
    };
    printing.enable = true;
    openssh.enable = false;
  };

  systemd.oomd = {
    enable = true;
    enableRootSlice = true;
    enableSystemSlice = true;
    enableUserSlices = true;
  };
}
