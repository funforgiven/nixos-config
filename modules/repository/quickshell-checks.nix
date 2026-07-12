{ config, ... }:
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
      shellConfig = homeConfig.programs.quickshell.configs.${shellConfigName};
      quickshell = homeConfig.programs.quickshell.package;
      quickshellRuntimeContracts = quickshell.overrideAttrs (previous: {
        cmakeFlags = (previous.cmakeFlags or [ ]) ++ [
          "-DBUILD_TESTING=ON"
          "-DCRASH_HANDLER=OFF"
          "-DUSE_JEMALLOC=OFF"
          "-DWAYLAND=OFF"
          "-DX11=OFF"
          "-DI3=OFF"
          "-DSERVICE_STATUS_NOTIFIER=OFF"
          "-DSERVICE_PIPEWIRE=OFF"
          "-DSERVICE_MPRIS=OFF"
          "-DSERVICE_PAM=OFF"
          "-DSERVICE_POLKIT=OFF"
          "-DSERVICE_GREETD=OFF"
          "-DSERVICE_UPOWER=OFF"
          "-DSERVICE_NOTIFICATIONS=OFF"
          "-DBLUETOOTH=OFF"
          "-DNETWORK=OFF"
        ];
        doCheck = true;
        checkPhase = ''
          runHook preCheck
          export QT_QPA_PLATFORM=offscreen
          ctest --output-on-failure --no-tests=error -R '^datastream$'
          ctest --output-on-failure --no-tests=error -R '^socketreconnect$'
          ./src/window/test/popupwindow clearAnchorItem
          runHook postCheck
        '';
      });
      desktopEntryProbeQml = pkgs.writeText "shell.qml" ''
        //@ pragma UseQApplication

        import QtQuick
        import Quickshell
        import "." as Generated

        ShellRoot {
            id: root

            readonly property var requiredIds: Generated.ShellConfig.pinnedDesktopIds

            function failures() {
                var result = [];
                for (var index = 0; index < root.requiredIds.length; index += 1) {
                    var id = root.requiredIds[index];
                    var entry = DesktopEntries.byId(id);
                    if (entry === null) {
                        result.push(id + ": missing");
                    } else if (!entry.command || entry.command.length === 0) {
                        result.push(id + ": no command");
                    } else if (!entry.icon || entry.icon.length === 0) {
                        result.push(id + ": no icon");
                    }
                }
                return result;
            }

            function validate() {
                var problems = root.failures();
                if (problems.length === 0) {
                    console.log("Desktop-entry contract passed for " + root.requiredIds.join(", "));
                    Qt.exit(0);
                }
            }

            Connections {
                target: DesktopEntries
                function onApplicationsChanged() {
                    root.validate();
                }
            }

            Timer {
                interval: 5000
                running: true
                onTriggered: {
                    console.error("Desktop-entry contract failed: " + root.failures().join("; "));
                    Qt.exit(1);
                }
            }

            Component.onCompleted: Qt.callLater(root.validate)
        }
      '';
      desktopEntryProbeQmldir = pkgs.writeText "qmldir" ''
        singleton ShellConfig 1.0 ShellConfig.qml
      '';
      desktopEntryProbe = pkgs.runCommandLocal "quickshell-desktop-entry-probe-source" { } ''
        mkdir -p "$out"
        install -m 0444 ${desktopEntryProbeQml} "$out/shell.qml"
        install -m 0444 ${desktopEntryProbeQmldir} "$out/qmldir"
        ln -s ${shellConfig}/generated/ShellConfig.qml "$out/ShellConfig.qml"
      '';
    in
    {
      checks = {
        quickshell-runtime-contracts = quickshellRuntimeContracts;
        quickshell-runtime-smoke =
          pkgs.runCommandLocal "quickshell-runtime-smoke"
            {
              nativeBuildInputs = [
                quickshell
                pkgs.coreutils
                pkgs.gnugrep
                pkgs.weston
              ];
            }
            ''
              set -euo pipefail

              export HOME="$TMPDIR/home"
              export XDG_CACHE_HOME="$TMPDIR/cache"
              export XDG_RUNTIME_DIR="$TMPDIR/runtime"
              export LC_ALL=C.UTF-8
              export XDG_DATA_DIRS="${homeConfig.home.path}/share:${hostConfig.system.path}/share"
              export XDG_CURRENT_DESKTOP=niri
              export QT_QPA_PLATFORM=wayland
              export QT_QUICK_BACKEND=software
              export WAYLAND_DISPLAY=wayland-smoke
              export NIRI_SOCKET="$TMPDIR/niri-missing.sock"
              export QS_DISABLE_FILE_WATCHER=1
              export QS_NO_RELOAD_POPUP=1
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
              qs_pid=
              cleanup() {
                if [[ -n "$qs_pid" ]]; then
                  kill "$qs_pid" 2>/dev/null || true
                  wait "$qs_pid" 2>/dev/null || true
                fi
                kill "$weston_pid" 2>/dev/null || true
                wait "$weston_pid" 2>/dev/null || true
              }
              trap cleanup EXIT

              for attempt in $(seq 1 100); do
                [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]] && break
                sleep 0.05
              done
              if [[ ! -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then
                cat "$TMPDIR/weston.log" >&2
                exit 1
              fi

              qs --no-color -v -p ${shellConfig} \
                >"$TMPDIR/quickshell.log" 2>&1 &
              qs_pid=$!

              loaded=false
              for attempt in $(seq 1 120); do
                if ! kill -0 "$qs_pid" 2>/dev/null; then
                  break
                fi
                if grep -Fq 'Configuration Loaded' "$TMPDIR/quickshell.log"; then
                  loaded=true
                  break
                fi
                sleep 0.05
              done
              if [[ "$loaded" != true ]]; then
                cat "$TMPDIR/quickshell.log" >&2
                cat "$TMPDIR/weston.log" >&2
                exit 1
              fi

              ipc_ready=false
              for attempt in $(seq 1 100); do
                set +e
                initial_state="$(qs ipc --pid "$qs_pid" call launcher isVisible 2>"$TMPDIR/ipc-error.log")"
                ipc_status=$?
                set -e
                if [[ "$ipc_status" -eq 0 ]]; then
                  ipc_ready=true
                  break
                fi
                sleep 0.05
              done
              if [[ "$ipc_ready" != true ]] || [[ "$initial_state" != false ]]; then
                cat "$TMPDIR/ipc-error.log" >&2
                echo "Launcher IPC did not become ready and closed; state=$initial_state" >&2
                exit 1
              fi

              qs ipc --pid "$qs_pid" call launcher open >/dev/null
              open_state="$(qs ipc --pid "$qs_pid" call launcher isVisible)"
              if [[ "$open_state" != true ]]; then
                echo "Launcher failed to open through its typed IPC boundary; state=$open_state" >&2
                exit 1
              fi

              qs ipc --pid "$qs_pid" call launcher close >/dev/null
              closed_state="$(qs ipc --pid "$qs_pid" call launcher isVisible)"
              if [[ "$closed_state" != false ]]; then
                echo "Launcher failed to close through its typed IPC boundary; state=$closed_state" >&2
                exit 1
              fi

              if ! kill -0 "$qs_pid" 2>/dev/null; then
                cat "$TMPDIR/quickshell.log" >&2
                exit 1
              fi
              if grep -Eq \
                'Failed to load configuration|Invalid property assignment| is not a type|TypeError|ReferenceError|Binding loop detected|Cannot read property [^ ]+ of null|Cannot anchor to an item' \
                "$TMPDIR/quickshell.log"; then
                cat "$TMPDIR/quickshell.log" >&2
                exit 1
              fi

              cleanup
              trap - EXIT
              touch "$out"
            '';

        quickshell-desktop-entries =
          pkgs.runCommandLocal "quickshell-desktop-entry-contract"
            {
              nativeBuildInputs = [ quickshell ];
            }
            ''
              set -euo pipefail

              export HOME="$TMPDIR/home"
              export XDG_CACHE_HOME="$TMPDIR/cache"
              export XDG_RUNTIME_DIR="$TMPDIR/runtime"
              export LC_ALL=C.UTF-8
              export XDG_DATA_DIRS="${homeConfig.home.path}/share:${hostConfig.system.path}/share"
              export QT_QPA_PLATFORM=offscreen
              export QS_DISABLE_FILE_WATCHER=1
              export QS_NO_RELOAD_POPUP=1
              mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
              chmod 0700 "$XDG_RUNTIME_DIR"

              qs -p ${desktopEntryProbe}
              touch "$out"
            '';

      };
    };
}
