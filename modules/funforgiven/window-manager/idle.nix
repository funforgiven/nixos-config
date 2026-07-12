{ config, ... }:
let
  configName = config.dendritic.quickshell.configName;
in
{
  home.gui =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      idleTimeoutSeconds = 30;
      cursorHideDelayMilliseconds = idleTimeoutSeconds * 1000;
      quickshell = lib.getExe' config.programs.quickshell.package "qs";
      swayidle = pkgs.swayidle.override {
        systemdSupport = false;
      };
      ipc =
        action:
        lib.escapeShellArgs [
          quickshell
          "-c"
          configName
          "ipc"
          "call"
          "amoled"
          action
        ];
      activateOverlay = ipc "activate";
      deactivateOverlay = ipc "deactivate";
    in
    {
      programs.niri.settings.cursor.hide-after-inactive-ms = cursorHideDelayMilliseconds;

      services.swayidle = {
        enable = true;
        package = swayidle;
        extraArgs = [ "-w" ];
        systemdTargets = [ "graphical-session.target" ];
        timeouts = [
          {
            timeout = idleTimeoutSeconds;
            command = activateOverlay;
            resumeCommand = deactivateOverlay;
          }
        ];
      };

      assertions = [
        {
          assertion = config.services.swayidle.extraArgs == [ "-w" ];
          message = "The AMOLED idle daemon must keep swayidle's wait mode enabled.";
        }
        {
          assertion =
            config.services.swayidle.timeouts == [
              {
                timeout = idleTimeoutSeconds;
                command = activateOverlay;
                resumeCommand = deactivateOverlay;
              }
            ];
          message = "The AMOLED idle daemon must have exactly one 30-second activate/deactivate timeout.";
        }
        {
          assertion =
            config.programs.niri.settings.cursor.hide-after-inactive-ms == cursorHideDelayMilliseconds;
          message = "Niri must hide the cursor on the AMOLED overlay's 30-second inactivity boundary.";
        }
        {
          assertion = lib.filterAttrs (_: command: command != null) config.services.swayidle.events == { };
          message = "The AMOLED idle daemon must not add lock, suspend, or resume event commands.";
        }
      ];

      systemd.user.services.swayidle = {
        Unit = {
          After = [ "quickshell.service" ];
          PartOf = [ "quickshell.service" ];
          Requires = [ "quickshell.service" ];
          Requisite = [ "graphical-session.target" ];
        };

        Service = {
          ExecCondition = [ "${lib.getExe config.programs.niri.package} msg --json version" ];
          ExecStopPost = "-${deactivateOverlay}";
          Restart = lib.mkForce "on-failure";
          RestartSec = 1;
          Slice = "background-graphical.slice";
          TimeoutStopSec = "10s";
        };
      };
    };
}
