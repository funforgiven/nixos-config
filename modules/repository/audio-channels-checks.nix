{
  config,
  lib,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    let
      hostConfig = config.flake.nixosConfigurations.parmigiano.config;

      audioctl = hostConfig.dendritic.audioControllerPackage;

      wirePlumberPolicySource =
        hostConfig.services.pipewire.wireplumber.extraScripts."funforgiven/channel-output-policy.lua";
      wirePlumberPolicy = pkgs.writeText "funforgiven-channel-output-policy.lua" wirePlumberPolicySource;
      faultWirePlumberPolicySource =
        builtins.replaceStrings
          [
            "local pending_resets = {}\n"
            "local function set_target_metadata (source, bridge, target_name)\n"
            "local function set_control_metadata (source, bridge, key, value)\n"
          ]
          [
            ''
              local pending_resets = {}
              local test_fault = os.getenv ("FUNFORGIVEN_AUDIO_POLICY_TEST_FAULT")
              local test_final_move_ack_failed = false
            ''
            ''
              local function set_target_metadata (source, bridge, target_name)
                if test_fault == "metadata-publish" and
                    target_name == "funforgiven.test.output.b" then
                  return false
                end
                if test_fault == "final-ack-live-rollback" and
                    test_final_move_ack_failed and
                    target_name == "funforgiven.test.output.a" then
                  return false
                end
            ''
            ''
              local function set_control_metadata (source, bridge, key, value)
                if test_fault == "final-ack-live-rollback" and
                    key == MOVE_ACK_KEY and type (value) == "string" and
                    not value:match (":armed$") then
                  test_final_move_ack_failed = true
                  return false
                end
            ''
          ]
          wirePlumberPolicySource;
      faultWirePlumberPolicyPackage = pkgs.writeTextDir "share/wireplumber/scripts/funforgiven/channel-output-policy.lua" faultWirePlumberPolicySource;
      wirePlumberConfigPackages = hostConfig.services.pipewire.wireplumber.configPackages;

      pipewire = hostConfig.services.pipewire.package;
      wireplumber = hostConfig.services.pipewire.wireplumber.package;
      wirePlumberDataDirs = hostConfig.systemd.user.services.wireplumber.environment.XDG_DATA_DIRS;
      pipewireConfigName = "20-funforgiven-audio-channels";
      pipewireConfigRoot = hostConfig.environment.etc.pipewire.source;
      pipewireModules =
        hostConfig.services.pipewire.extraConfig.pipewire.${pipewireConfigName}."context.modules";
      expectedPipewireModules = pkgs.writeText "funforgiven-audio-modules.json" (
        builtins.toJSON pipewireModules
      );
      pipewireTestConfig = pkgs.runCommandLocal "funforgiven-audio-integration-pipewire-config" { } ''
        mkdir -p "$out/share/pipewire"
        for config_file in ${pipewire}/share/pipewire/*.conf; do
          ln -s "$config_file" "$out/share/pipewire/$(basename "$config_file")"
        done
        ln -s ${pipewireConfigRoot}/pipewire.conf.d "$out/share/pipewire/pipewire.conf.d"
      '';
      integrationScript = ../audio-channels/tests/integration.sh;
      audioctlInterruptTest = ../audio-channels/tests/audioctl-interrupt.test.sh;
      audioctlTest = ../audio-channels/tests/audioctl.test.sh;
      graphContract = ../audio-channels/tests/graph-contract.mjs;
    in
    {
      checks = {
        audio-channels-audioctl =
          pkgs.runCommandLocal "funforgiven-audioctl-check"
            {
              nativeBuildInputs = [
                pkgs.jq
                pkgs.shellcheck
              ];
            }
            ''
              set -euo pipefail

              audioctl=${lib.escapeShellArg (lib.getExe' audioctl "funforgiven-audioctl")}
              test -x "$audioctl"
              shellcheck "$audioctl"
              shellcheck -e SC1090,SC2034,SC2154 ${audioctlInterruptTest}
              shellcheck -e SC1090,SC2034 ${audioctlTest}
              shellcheck ${integrationScript}
              grep -Fq 'target node ID $target_id is in the PipeWire error state' "$audioctl"
              AUDIOCTL_SOURCE="$audioctl" bash ${audioctlTest}

              mkdir -p "$out/bin"
              ln -s "$audioctl" "$out/bin/funforgiven-audioctl"
            '';

        audio-channels-wireplumber-lua =
          pkgs.runCommandLocal "funforgiven-channel-output-policy-lua-check" { }
            ''
              set -euo pipefail

              ${pkgs.lua5_4}/bin/luac -p ${wirePlumberPolicy}
              ${pkgs.lua5_4}/bin/luac -p ${faultWirePlumberPolicyPackage}/share/wireplumber/scripts/funforgiven/channel-output-policy.lua
              grep -Fq 'local node_state = candidate:get_state ()' ${wirePlumberPolicy}
              grep -Fq 'linking_utils.haveAvailableRoutes (props, devices_om)' ${wirePlumberPolicy}
              grep -Fq '"event.subject.param-id", "c", "Route", "EnumRoute"' ${wirePlumberPolicy}
              grep -Fq 'local saved, save_error = state:save (state_table)' ${wirePlumberPolicy}
              grep -Fq 'live_restored, durable_saved, "state-save"' ${wirePlumberPolicy}
              grep -Fq 'return "rollback-incomplete"' ${wirePlumberPolicy}
              grep -Fq 'test_final_move_ack_failed = true' ${faultWirePlumberPolicyPackage}/share/wireplumber/scripts/funforgiven/channel-output-policy.lua
              grep -Fq '18446744073709551615' ${wirePlumberPolicy}

              policy_configs=()
              for package in ${lib.escapeShellArgs (map toString wirePlumberConfigPackages)}; do
                candidate="$package/share/wireplumber/wireplumber.conf.d/21-funforgiven-channel-output-policy.conf"
                if [[ -f "$candidate" ]]; then
                  policy_configs+=("$candidate")
                fi
              done

              if (( ''${#policy_configs[@]} != 1 )); then
                echo "Expected exactly one raw WirePlumber component configuration, found ''${#policy_configs[@]}." >&2
                exit 1
              fi

              policy_config="''${policy_configs[0]}"
              grep -Eq '^[[:space:]]*requires = \[ metadata\.default \][[:space:]]*$' "$policy_config"
              grep -Eq '^[[:space:]]*before = \[ support\.standard-event-source \][[:space:]]*$' "$policy_config"
              grep -Eq '^[[:space:]]*custom\.funforgiven-channel-output-policy = required[[:space:]]*$' "$policy_config"
              [[ $(grep -Ec '^[[:space:]]*custom\.funforgiven-channel-output-policy = required[[:space:]]*$' "$policy_config") -eq 2 ]]
              if grep -Eq 'requires = \[ *"|before = \[ *"' "$policy_config"; then
                echo "WirePlumber component dependencies must remain bare SPA-JSON identifiers." >&2
                exit 1
              fi

              mkdir -p "$out"
              ln -s ${wirePlumberPolicy} "$out/channel-output-policy.lua"
              ln -s "$policy_config" "$out/component.conf"
            '';

        audio-channels-pipewire-config =
          pkgs.runCommandLocal "funforgiven-audio-pipewire-config-check"
            {
              nativeBuildInputs = [ pkgs.jq ];
            }
            ''
              set -euo pipefail

              config_dir=${lib.escapeShellArg "${pipewireConfigRoot}/pipewire.conf.d"}
              config_name=${lib.escapeShellArg "${pipewireConfigName}.conf"}
              test -f "$config_dir/$config_name"

              export HOME="$TMPDIR/home"
              export PIPEWIRE_CONFIG_DIR="$config_dir"
              mkdir -p "$HOME"

              ${pipewire}/bin/pw-config \
                -N \
                -n "$config_name" \
                merge context.modules \
                > parsed-modules.json

              jq -e --slurpfile expected ${expectedPipewireModules} '
                def expected_ids: ["system", "game", "voice", "music"];

                . == $expected[0]
                and type == "array"
                and length == 4
                and [.[].args."capture.props"."funforgiven.audio.channel"] == expected_ids
                and [.[].args."playback.props"."funforgiven.audio.channel"] == expected_ids
                and (
                  [
                    .[].args."capture.props"."node.name",
                    .[].args."playback.props"."node.name"
                  ]
                  | length == 8 and (unique | length == 8)
                )
                and all(
                  .[];
                  .args as $args
                  | $args."capture.props" as $sink
                  | $args."playback.props" as $bridge
                  | $sink."funforgiven.audio.channel" as $id
                  | .name == "libpipewire-module-loopback"
                    and $args."audio.position" == ["FL", "FR"]
                    and $sink."funforgiven.audio.kind" == "sink"
                    and $sink."media.class" == "Audio/Sink"
                    and $sink."node.virtual" == true
                    and $sink."node.name" == ("funforgiven.audio.channel." + $id)
                    and (
                      if $id == "system" then
                        $sink."priority.session" == 2000
                      else
                        $sink."priority.session" == 100
                      end
                    )
                    and $bridge."funforgiven.audio.channel" == $id
                    and $bridge."funforgiven.audio.kind" == "bridge"
                    and $bridge."node.name" == ($sink."node.name" + ".output")
                    and $bridge."application.id" == $bridge."node.name"
                    and $bridge."node.passive" == true
                    and $bridge."node.dont-fallback" == true
                    and $bridge."node.linger" == true
                    and $bridge."target.object" == "-1"
                )
                and (
                  [
                    paths as $path
                    | $path[-1]
                    | select(. == "node.target")
                  ]
                  | length == 0
                )
                and (
                  [
                    paths as $path
                    | select($path[-1] == "target.object")
                    | { path: $path, value: getpath($path) }
                  ] as $target_objects
                  | ($target_objects | length) == 4
                    and all(
                      $target_objects[];
                      .value == "-1"
                      and .path[1:] == ["args", "playback.props", "target.object"]
                    )
                )
              ' parsed-modules.json >/dev/null

              mkdir -p "$out"
              install -m 0444 parsed-modules.json "$out/context-modules.json"
            '';

        audio-channels-integration =
          pkgs.runCommandLocal "funforgiven-audio-channels-integration"
            {
              nativeBuildInputs = [
                audioctl
                pipewire
                wireplumber
                pkgs.coreutils
                pkgs.gnugrep
                pkgs.jq
                pkgs.nodejs
                pkgs.pulseaudio
              ];
              PIPEWIRE_TEST_CONFIG = pipewireTestConfig;
              WIREPLUMBER_TEST_DATA_DIRS = wirePlumberDataDirs;
              WIREPLUMBER_FAULT_TEST_DATA_DIRS = "${faultWirePlumberPolicyPackage}/share:${wirePlumberDataDirs}";
              AUDIOCTL = lib.getExe' audioctl "funforgiven-audioctl";
              AUDIOCTL_INTERRUPT_HELPER = audioctlInterruptTest;
              AUDIO_GRAPH_CHECK = graphContract;
            }
            ''
              bash ${integrationScript}
            '';
      };
    };
}
