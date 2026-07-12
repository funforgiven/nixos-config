{ config, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      hostName = "parmigiano";
      hostModel = config.dendritic.hosts.${hostName};
      userName = config.users.${hostModel.user}.username;
      homeConfigurationName = "${userName}@${hostName}";
      shellConfigName = config.dendritic.quickshell.configName;
      hostEvaluation = config.flake.nixosConfigurations.${hostName};
      homeEvaluation = config.flake.homeConfigurations.${homeConfigurationName};
      hostConfig = hostEvaluation.config;
      homeConfig = homeEvaluation.config;
      nestedHomeConfig = hostConfig.home-manager.users.${userName};
      quickshell = homeConfig.programs.quickshell.package;
      nativeHostModel = lib.recursiveUpdate hostModel {
        polkit.agent = "quickshell";
      };
      nativeHostEvaluation = config.dendritic.builders.mkNixosConfiguration hostName nativeHostModel;
      nativeHomeEvaluation = config.dendritic.builders.mkHomeConfiguration hostName nativeHostModel;
      nativeHostConfig = nativeHostEvaluation.config;
      nativeHomeConfig = nativeHomeEvaluation.config;
      nativeNestedHomeConfig = nativeHostConfig.home-manager.users.${userName};
      nativeShellConfig = nativeHomeConfig.programs.quickshell.configs.${shellConfigName};
      nativeNestedShellConfig = nativeNestedHomeConfig.programs.quickshell.configs.${shellConfigName};
      nativeQuickshell = nativeHomeConfig.programs.quickshell.package;
      nixosOnlyOverride = builtins.tryEval (
        builtins.deepSeq
          (hostEvaluation.extendModules {
            modules = [
              {
                dendritic.polkit.agent = lib.mkForce "quickshell";
              }
            ];
          }).config.system.build.toplevel.drvPath
          true
      );
      nestedOnlyOverride = builtins.tryEval (
        builtins.deepSeq
          (hostEvaluation.extendModules {
            modules = [
              {
                home-manager.users.${userName}.dendritic.polkit.agent = lib.mkForce "quickshell";
              }
            ];
          }).config.system.build.toplevel.drvPath
          true
      );
      runtimeValidatorFor =
        label: evaluatedHomeConfig:
        lib.findFirst (package: lib.getName package == "funforgiven-runtime-check")
          (throw "funforgiven-runtime-check is missing from the ${label} Home Manager profile")
          evaluatedHomeConfig.home.packages;
      defaultRuntimeExpected = (runtimeValidatorFor "default" homeConfig).runtimeValidationExpected;
      nativeRuntimeExpected =
        (runtimeValidatorFor "native standalone" nativeHomeConfig).runtimeValidationExpected;
      nativeNestedRuntimeExpected =
        (runtimeValidatorFor "native nested" nativeNestedHomeConfig).runtimeValidationExpected;
    in
    {
      checks = {
        quickshell-native-polkit-smoke =
          pkgs.runCommandLocal "quickshell-native-polkit-smoke"
            {
              nativeBuildInputs = [
                nativeQuickshell
                pkgs.coreutils
                pkgs.gnugrep
                pkgs.jq
                pkgs.weston
              ];
            }
            ''
              set -euo pipefail

              test ${lib.escapeShellArg nativeHostConfig.dendritic.polkit.agent} = quickshell
              test ${lib.escapeShellArg nativeHomeConfig.dendritic.polkit.agent} = quickshell
              test ${lib.escapeShellArg nativeNestedHomeConfig.dendritic.polkit.agent} = quickshell
              test ${lib.escapeShellArg homeConfig.dendritic.polkit.agent} = ${lib.escapeShellArg hostConfig.dendritic.polkit.agent}
              test ${lib.escapeShellArg nestedHomeConfig.dendritic.polkit.agent} = ${lib.escapeShellArg hostConfig.dendritic.polkit.agent}
              test ${lib.escapeShellArg (toString homeConfig.programs.quickshell.package)} = ${lib.escapeShellArg (toString nestedHomeConfig.programs.quickshell.package)}
              test ${lib.escapeShellArg (lib.boolToString nixosOnlyOverride.success)} = false
              test ${lib.escapeShellArg (lib.boolToString nestedOnlyOverride.success)} = false
              test ${lib.escapeShellArg (lib.boolToString nativeHostConfig.systemd.user.services.niri-flake-polkit.enable)} = false
              test ${lib.escapeShellArg (toString nativeQuickshell)} != ${lib.escapeShellArg (toString quickshell)}
              test ${lib.escapeShellArg (toString nativeQuickshell)} = ${lib.escapeShellArg (toString nativeNestedHomeConfig.programs.quickshell.package)}
              grep -Fq 'readonly property bool nativePolkitEnabled: true' \
                ${nativeShellConfig}/generated/ShellConfig.qml
              grep -Fq 'readonly property bool nativePolkitEnabled: true' \
                ${nativeNestedShellConfig}/generated/ShellConfig.qml
              jq -e '.polkitAgent == "kde"' ${defaultRuntimeExpected} >/dev/null
              jq -e '.polkitAgent == "quickshell"' ${nativeRuntimeExpected} >/dev/null
              jq -e '.polkitAgent == "quickshell"' ${nativeNestedRuntimeExpected} >/dev/null
              [[ ${lib.escapeShellArg (builtins.head nativeHomeConfig.systemd.user.services.quickshell.Service.ExecStart)} \
                == ${lib.escapeShellArg "${nativeQuickshell}/bin/quickshell --config ${shellConfigName}"} ]]
              test -e ${nativeHomeEvaluation.activationPackage}
              test -e ${nativeHostConfig.system.build.toplevel}

              export HOME="$TMPDIR/home"
              export XDG_CACHE_HOME="$TMPDIR/cache"
              export XDG_RUNTIME_DIR="$TMPDIR/runtime"
              export LC_ALL=C.UTF-8
              export XDG_DATA_DIRS="${nativeHomeConfig.home.path}/share:${nativeHostConfig.system.path}/share"
              export XDG_CURRENT_DESKTOP=niri
              export QT_QPA_PLATFORM=wayland
              export QT_QUICK_BACKEND=software
              export WAYLAND_DISPLAY=wayland-native-polkit-smoke
              export NIRI_SOCKET="$TMPDIR/niri-missing.sock"
              export QS_DISABLE_FILE_WATCHER=1
              export QS_NO_RELOAD_POPUP=1
              export DBUS_SYSTEM_BUS_ADDRESS="unix:path=$TMPDIR/no-system-bus"
              export DBUS_SESSION_BUS_ADDRESS="unix:path=$TMPDIR/no-session-bus"
              mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
              chmod 0700 "$XDG_RUNTIME_DIR"

              weston \
                --backend=headless \
                --renderer=pixman \
                --shell=kiosk \
                --socket="$WAYLAND_DISPLAY" \
                --idle-time=0 \
                --width=1920 \
                --height=1080 \
                --no-config \
                --log="$TMPDIR/weston.log" &
              weston_pid=$!
              trap 'kill "$weston_pid" 2>/dev/null || true' EXIT

              for attempt in $(seq 1 100); do
                [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]] && break
                sleep 0.05
              done
              if [[ ! -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then
                cat "$TMPDIR/weston.log" >&2
                exit 1
              fi

              set +e
              timeout --signal=TERM --kill-after=2s 10s \
                qs --no-color -v -p ${nativeShellConfig} \
                >"$TMPDIR/quickshell.log" 2>&1
              qs_status=$?
              set -e

              if [[ "$qs_status" -ne 124 ]] \
                || ! grep -Fq 'Configuration Loaded' "$TMPDIR/quickshell.log"; then
                cat "$TMPDIR/quickshell.log" >&2
                cat "$TMPDIR/weston.log" >&2
                exit 1
              fi
              if grep -Eq \
                'Failed to load configuration|Invalid property assignment| is not a type|TypeError|ReferenceError|Binding loop detected|Cannot read property [^ ]+ of null|Cannot anchor to an item' \
                "$TMPDIR/quickshell.log"; then
                cat "$TMPDIR/quickshell.log" >&2
                exit 1
              fi

              kill "$weston_pid" 2>/dev/null || true
              wait "$weston_pid" 2>/dev/null || true
              trap - EXIT
              touch "$out"
            '';
      };
    };
}
