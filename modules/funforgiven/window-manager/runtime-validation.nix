{
  config,
  lib,
  ...
}:
let
  shellConfigName = config.dendritic.quickshell.configName;
  sessionShutdown = config.dendritic.sessionShutdown;
  expected = {
    configName = shellConfigName;
    physicalKeyboardNames = [ "Turkish" ];
    channels = map (channel: {
      inherit (channel)
        bridgeName
        id
        sinkName
        ;
    }) config.dendritic.audio.channels;
    kdePolkitProcess = "polkit-kde-authentication-agent-1";
    sessionShutdown = {
      applicationStopTimeout = "${toString sessionShutdown.applicationStopTimeoutSeconds}s";
      applicationStopTimeoutEnvironment = "APPLICATION_STOP_TIMEOUT_SECONDS=${toString sessionShutdown.applicationStopTimeoutSeconds}";
      authorizationTimeoutEnvironment = "AUTHORIZATION_TIMEOUT_SECONDS=${toString sessionShutdown.authorizationTimeoutSeconds}";
      coordinatorTimeout = "${toString sessionShutdown.coordinatorTimeoutSeconds}s";
      inhibitDelayMaxUSec = sessionShutdown.inhibitDelayMaxSeconds * 1000000;
      inherit (sessionShutdown) actionUnits;
    };
  };
in
{
  home.gui =
    {
      config,
      pkgs,
      ...
    }:
    let
      outputModel = lib.throwIfNot (
        config.dendritic.niri.outputs != null
      ) "Runtime validation requires host-specific Niri output facts." config.dendritic.niri.outputs;
      homeExpected = expected // {
        outputs = map (output: output.connector) (builtins.attrValues outputModel);
        polkitAgent = config.dendritic.polkit.agent;
        niriExecutable = lib.getExe config.programs.niri.package;
        quickshellExecutable = "${config.programs.quickshell.package}/bin/.quickshell-wrapped";
      };
      expectedJson = pkgs.writeText "funforgiven-runtime-expected.json" (builtins.toJSON homeExpected);
      validator =
        (pkgs.writeShellApplication {
          name = "funforgiven-runtime-check";
          runtimeInputs = [
            config.i18n.inputMethod.package
            config.programs.niri.package
            config.programs.quickshell.package
            pkgs.coreutils
            pkgs.jq
            pkgs.nodejs
            pkgs.pipewire
            pkgs.systemd
          ];
          text = ''
            export RUNTIME_VALIDATION_EXPECTED=${lib.escapeShellArg expectedJson}
            export RUNTIME_VALIDATION_GRAPH_CHECK=${lib.escapeShellArg ../../audio-channels/tests/graph-contract.mjs}
            ${builtins.readFile ./runtime-validation.sh}
          '';
          meta.description = "Read-only deployed Niri/Quickshell/audio runtime acceptance check";
        }).overrideAttrs
          (previous: {
            passthru = (previous.passthru or { }) // {
              runtimeValidationExpected = expectedJson;
            };
          });
    in
    {
      home.packages = [ validator ];
    };
}
