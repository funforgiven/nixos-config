{
  config,
  lib,
  ...
}:
let
  actions = [
    "logout"
    "reboot"
    "poweroff"
  ];
  actionUnits = lib.genAttrs actions (action: "funforgiven-session-${action}.service");
  cfg = config.dendritic.sessionShutdown;
  applicationDrainOverheadSeconds = 3;
  coordinatorOverheadSeconds = 3;
  shutdown =
    lib.throwIfNot
      (cfg.applicationStopTimeoutSeconds + applicationDrainOverheadSeconds < cfg.inhibitDelayMaxSeconds)
      "The session shutdown inhibitor window must exceed the application stop timeout and bounded cleanup overhead."
      (
        lib.throwIfNot
          (
            cfg.authorizationTimeoutSeconds + cfg.inhibitDelayMaxSeconds + coordinatorOverheadSeconds
            < cfg.coordinatorTimeoutSeconds
          )
          "The session shutdown coordinator timeout must cover authorization, the inhibitor window, and bounded overhead."
          cfg
      );
  applicationStopTimeout = "${toString shutdown.applicationStopTimeoutSeconds}s";
  inhibitDelayMax = "${toString shutdown.inhibitDelayMaxSeconds}s";
  coordinatorTimeout = "${toString shutdown.coordinatorTimeoutSeconds}s";
in
{
  options.dendritic.sessionShutdown = {
    applicationStopTimeoutSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10;
      description = "Maximum time graphical applications receive after SIGTERM before SIGKILL.";
    };

    inhibitDelayMaxSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 15;
      description = "Hard login1 delay-inhibitor ceiling for staged reboot and poweroff.";
    };

    authorizationTimeoutSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = "Maximum time to wait for an interactive machine-action authorization.";
    };

    coordinatorTimeoutSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 80;
      description = "Maximum time for authorization and one supervised session-exit action.";
    };

    actionUnits = lib.mkOption {
      type = lib.types.attrsOf lib.types.singleLineStr;
      readOnly = true;
      internal = true;
      description = "Generated systemd user units forming the narrow session-action interface.";
    };
  };

  config = {
    dendritic.sessionShutdown.actionUnits = actionUnits;

    nixos.modules.session-shutdown.services.logind.settings.Login.InhibitDelayMaxSec = inhibitDelayMax;

    home.gui =
      { pkgs, ... }:
      let
        coordinator = pkgs.writeShellApplication {
          name = "funforgiven-session-shutdown";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.jq
            pkgs.systemd
          ];
          text = builtins.readFile ./session-shutdown.sh;
          meta.description = "Bounded graceful Niri session shutdown coordinator";
        };
        coordinatorExecutable = lib.getExe coordinator;
        coordinatorLock = "%t/funforgiven-session-shutdown.lock";
        actionDescriptions = {
          logout = "Gracefully log out of the Niri session";
          reboot = "Gracefully stop the Niri session before reboot";
          poweroff = "Gracefully stop the Niri session before poweroff";
        };
        actionService = action: {
          Unit = {
            Description = actionDescriptions.${action};
            Documentation = [
              "man:systemd-inhibit(1)"
              "man:systemd.service(5)"
            ];
          };

          Service = {
            Type = "oneshot";
            Environment = [
              "APPLICATION_STOP_TIMEOUT_SECONDS=${toString shutdown.applicationStopTimeoutSeconds}"
              "AUTHORIZATION_TIMEOUT_SECONDS=${toString shutdown.authorizationTimeoutSeconds}"
            ];
            ExecStart = lib.escapeShellArgs [
              (lib.getExe' pkgs.util-linux "flock")
              "--nonblock"
              "--conflict-exit-code"
              "75"
              coordinatorLock
              coordinatorExecutable
              action
            ];
            Slice = "session.slice";
            TimeoutStartSec = coordinatorTimeout;
          };
        };
      in
      {
        systemd.user = {
          settings.Manager.DefaultTimeoutStopSec = applicationStopTimeout;
          services = lib.mapAttrs' (
            action: unit: lib.nameValuePair (lib.removeSuffix ".service" unit) (actionService action)
          ) actionUnits;
        };
      };
  };
}
