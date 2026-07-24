test -f "$shell_config/shell.qml"

rg --quiet --fixed-strings 'if (!this->mItem) {' "$runtime_patch"
rg --quiet --fixed-strings 'this->setWindowInternal(nullptr);' "$runtime_patch"
rg --quiet --fixed-strings 'void TestPopupWindow::clearAnchorItem()' "$runtime_patch"
rg --quiet --fixed-strings 'anchor.setItem(nullptr);' "$runtime_patch"

audio_actions="$shell_config/services/AudioActions.qml"
audio_service="$shell_config/services/AudioService.qml"
app_service="$shell_config/services/AppService.qml"
niri_service="$shell_config/services/NiriService.qml"
session_actions="$shell_config/services/SessionActions.qml"
session_command="$shell_config/services/SessionCommand.js"

rg --quiet --fixed-strings 'var seenStreamRefs = Object.create(null);' "$audio_actions"
rg --quiet --fixed-strings 'var actionable = live.filter(function (streamRef)' "$audio_actions"
rg --quiet --fixed-strings 'if (actionable.length === 0)' "$audio_actions"
rg --quiet --fixed-strings 'readonly property int helperCommandTimeoutMs: 12000' "$audio_actions"
rg --quiet --fixed-strings 'readonly property int graphConfirmationTimeoutMs: 6000' "$audio_actions"
rg --quiet --fixed-strings 'operation.deadline = Date.now() + helperCommandTimeoutMs;' "$audio_actions"
rg --multiline --multiline-dotall --quiet \
  'operation\.phase = "graph";[[:space:]]*operation\.deadline = Date\.now\(\) \+ graphConfirmationTimeoutMs;[[:space:]]*_reconcile\(requestId\);' \
  "$audio_actions"
rg --quiet --fixed-strings 'AudioRouting.resolveSelection(normalized, AudioService.playbackStreams)' "$audio_actions"
rg --quiet --fixed-strings '_preflightError(operation, message)' "$audio_actions"

rg --quiet --fixed-strings 'isStream: node.isStream' "$audio_service"
rg --quiet --fixed-strings 'var signature = AudioModel.snapshotSignature(snapshot);' "$audio_service"
rg --quiet --fixed-strings 'interval: root.graphSettleMs' "$audio_service"
rg --quiet --fixed-strings '_resolvePresentation, Pipewire.ready);' "$audio_service"
rg --quiet --fixed-strings 'return AudioModel.isSelectableOutput(output, outputId, outputSerial, channelId);' "$audio_service"

rg --quiet --fixed-strings 'process.command = root._launchCommand(entry);' "$app_service"
rg --quiet --fixed-strings 'return LaunchCommand.app2unitService(' "$app_service"
rg --quiet --fixed-strings 'function app2unitService(launcher, id, applicationStopTimeout)' \
  "$shell_config/services/LaunchCommand.js"
rg --quiet --fixed-strings 'desktopEntryId(id)' "$shell_config/services/LaunchCommand.js"
! rg --quiet --fixed-strings '"--property=JobTimeoutSec=' "$shell_config/services"
rg --quiet --fixed-strings 'desktop-entry launcher did not complete its start job within 7 seconds' "$app_service"
rg --quiet --fixed-strings '"app-graphical.slice"' "$shell_config/services/LaunchCommand.js"
rg --quiet --fixed-strings '"TimeoutStopSec=" + stopTimeout' "$shell_config/services/LaunchCommand.js"
rg --quiet --fixed-strings '"KillMode=control-group"' "$shell_config/services/LaunchCommand.js"
rg --quiet --fixed-strings '"KillSignal=SIGTERM"' "$shell_config/services/LaunchCommand.js"
rg --quiet --fixed-strings '"SendSIGKILL=yes"' "$shell_config/services/LaunchCommand.js"
! rg --quiet --fixed-strings 'entry.execute()' "$app_service"
! rg --quiet --fixed-strings 'Quickshell.execDetached' "$app_service"
rg --quiet --fixed-strings 'function launcherApplications(revision)' "$app_service"
rg --quiet --fixed-strings 'entry.noDisplay === true || entry.hidden === true' "$app_service"
rg --quiet --fixed-strings 'keywords: root._textList(entry.keywords)' "$app_service"
rg --quiet --fixed-strings 'property var pendingDesktopIds: []' "$app_service"
rg --quiet --fixed-strings 'function isLaunchPending(desktopId)' "$app_service"
rg --quiet --fixed-strings 'if (root.isLaunchPending(entry.id))' "$app_service"
rg --quiet --fixed-strings 'root._beginLaunch(process);' "$app_service"
rg --quiet --fixed-strings 'root._reportLaunchSuccess(process.desktopId);' "$app_service"
rg --quiet --fixed-strings \
  'root._reportLaunchFailure(process.desktopId, detail || "desktop-entry launcher exited with code " + exitCode);' \
  "$app_service"
rg --quiet --fixed-strings 'var canonicalId = AppIdentity.windowCanonicalId(' "$app_service"

rg --quiet --fixed-strings 'function focusMonitor(output)' \
  "$shell_config/services/NiriProtocol.js"
rg --quiet --fixed-strings 'function focusMonitor(output)' "$niri_service"
rg --quiet --fixed-strings \
  'return root._enqueueAction("focus-monitor", NiriProtocol.focusMonitor(output));' \
  "$niri_service"
rg --quiet --fixed-strings '_abortActionQueue("niri event state became stale: " + message)' "$niri_service"
rg --quiet --fixed-strings 'if (!root.connected || root.stale)' "$niri_service"
rg --quiet --fixed-strings 'if (!root._eventGenerationHealthy && root.connected && !root.stale)' "$niri_service"
test "$(rg --count --fixed-strings 'root._eventReconnectAttempt = 0;' "$niri_service")" -eq 1
! rg --quiet --fixed-strings 'skip_confirmation' \
  "$shell_config/services/NiriProtocol.js" "$niri_service"
! rg --quiet --fixed-strings 'NiriProtocol.quit' \
  "$shell_config/services/NiriProtocol.js" "$niri_service"
rg --quiet --fixed-strings 'next._initialWorkspacesReceived' \
  "$shell_config/services/NiriState.js"
rg --quiet --fixed-strings 'next._initialWindowsReceived' \
  "$shell_config/services/NiriState.js"
rg --multiline --multiline-dotall --quiet \
  'property Socket _actionSocket: Socket \{.*?onConnectedChanged: \{[[:space:]]*if \(root\._resettingActionTransport\)' \
  "$niri_service"

rg --quiet 'readonly property string appLauncher: "/nix/store/.+/bin/app2unit"' \
  "$shell_config/generated/ShellConfig.qml"
! rg --quiet 'terminalExecutable|launchEnvironmentNames' \
  "$shell_config/generated/ShellConfig.qml" "$app_service"
rg --quiet \
  'readonly property string audioController: "/nix/store/.+/bin/funforgiven-audioctl"' \
  "$shell_config/generated/ShellConfig.qml"
rg --quiet \
  'readonly property string systemctl: "/nix/store/.+-systemd-[^"]+/bin/systemctl"' \
  "$shell_config/generated/ShellConfig.qml"
rg --quiet --fixed-strings 'readonly property string applicationStopTimeout: "10s"' \
  "$shell_config/generated/ShellConfig.qml"
rg --quiet --fixed-strings \
  'readonly property var sessionActionUnits: ({"logout":"funforgiven-session-logout.service","poweroff":"funforgiven-session-poweroff.service","reboot":"funforgiven-session-reboot.service"})' \
  "$shell_config/generated/ShellConfig.qml"

test -f "$session_actions"
test -f "$session_command"
rg --quiet --fixed-strings 'singleton SessionActions 1.0 SessionActions.qml' \
  "$shell_config/services/qmldir"
rg --quiet --fixed-strings 'readonly property bool busy: root.activeAction.length > 0' \
  "$session_actions"
rg --quiet --fixed-strings 'readonly property int confirmationTimeoutMs: 5000' \
  "$session_actions"
rg --quiet --fixed-strings 'if (root.armedAction !== action)' "$session_actions"
rg --quiet --fixed-strings 'SessionCommand.sessionAction(' \
  "$session_actions"
rg --quiet --fixed-strings 'Shell.ShellConfig.sessionActionUnits' "$session_actions"
rg --quiet --fixed-strings 'action !== "logout" && action !== "reboot" && action !== "poweroff"' \
  "$session_command"
rg --quiet --fixed-strings 'if (!binary.startsWith("/"))' "$session_command"
rg --quiet --fixed-strings 'return [binary, "--user", "start", unit];' \
  "$session_command"
rg --quiet --fixed-strings 'stderr: StdioCollector {' "$session_actions"
rg --quiet --fixed-strings 'process.errorText || process.outputText' "$session_actions"
rg --quiet --fixed-strings 'root.failedAction = action;' "$session_actions"
rg --quiet --fixed-strings 'root.error = detail;' "$session_actions"
! rg --quiet -- '(--force|--check-inhibitors|"-i"|NiriService\.quit|NiriProtocol\.quit)' \
  "$session_actions" "$session_command"

mkdir -p \
  "$TMPDIR/app2unit-empty" \
  "$TMPDIR/app2unit-home" \
  "$TMPDIR/app2unit-data/applications"
ln -s "$app2unit_probe_desktop" "$TMPDIR/app2unit-data/applications/firefox.desktop"
app2unit_output="$(
  HOME="$TMPDIR/app2unit-home" \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    XDG_CURRENT_DESKTOP=niri \
    XDG_DATA_HOME="$TMPDIR/app2unit-data" \
    XDG_DATA_DIRS="$TMPDIR/app2unit-empty" \
    app2unit --test \
      -t service \
      -s app-graphical.slice \
      -p TimeoutStopSec=10s \
      -p KillMode=control-group \
      -p KillSignal=SIGTERM \
      -p SendSIGKILL=yes \
      -- firefox.desktop
)"
rg --quiet --fixed-strings '>--property=Type=exec<' <<<"$app2unit_output"
rg --quiet --fixed-strings '>--property=ExitType=cgroup<' <<<"$app2unit_output"
rg --quiet --fixed-strings '>--working-directory=/tmp<' <<<"$app2unit_output"
rg --quiet --fixed-strings '>--property=After=graphical-session.target<' <<<"$app2unit_output"
rg --quiet --fixed-strings '>--property=PartOf=graphical-session.target<' <<<"$app2unit_output"
rg --quiet --fixed-strings '>--property=SourcePath=' <<<"$app2unit_output"
rg --quiet --fixed-strings '>--property=TimeoutStopSec=10s<' <<<"$app2unit_output"
rg --quiet --fixed-strings '>--property=KillMode=control-group<' <<<"$app2unit_output"
rg --quiet --fixed-strings '>--property=KillSignal=SIGTERM<' <<<"$app2unit_output"
rg --quiet --fixed-strings '>--property=SendSIGKILL=yes<' <<<"$app2unit_output"
rg --quiet --fixed-strings '>--slice=app-graphical.slice<' <<<"$app2unit_output"
rg --quiet --fixed-strings '>--unit=app-niri-firefox@' <<<"$app2unit_output"
rg --quiet --fixed-strings ">$true_executable<" <<<"$app2unit_output"
rg --quiet --fixed-strings '>two words<' <<<"$app2unit_output"
! rg --quiet 'JobTimeout(Sec|USec)' <<<"$app2unit_output"
