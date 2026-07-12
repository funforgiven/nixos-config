_: {
  nixos.modules.power = {
    powerManagement.cpuFreqGovernor = "performance";

    services = {
      logind.settings.Login = {
        IdleAction = "ignore";
        IdleActionSec = "0";
        HandleSuspendKey = "ignore";
        HandleHibernateKey = "ignore";
        HandleLidSwitch = "ignore";
        HandleLidSwitchExternalPower = "ignore";
        HandleLidSwitchDocked = "ignore";
      };
      upower.enable = false;
      power-profiles-daemon.enable = false;
    };

    systemd.oomd = {
      enableRootSlice = true;
      enableSystemSlice = true;
      enableUserSlices = true;
    };

    systemd.sleep.settings.Sleep = {
      AllowSuspend = "no";
      AllowHibernation = "no";
      AllowHybridSleep = "no";
      AllowSuspendThenHibernate = "no";
    };
  };
}
