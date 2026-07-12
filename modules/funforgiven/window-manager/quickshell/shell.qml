//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import "."
import "bar" as Bar
import "dock" as Dock
import "idle" as Idle
import "launcher" as Launcher
import "mixer" as Mixer
import "polkit" as Polkit
import "services" as Services

ShellRoot {
    id: root

    readonly property string configurationName: ShellConfig.configName

    readonly property var niriService: Services.NiriService
    readonly property var appService: Services.AppService
    readonly property var audioService: Services.AudioService
    readonly property var audioActions: Services.AudioActions
    readonly property var launcherController: Launcher.Launcher
    readonly property var polkitOverlay: Polkit.PolkitOverlay

    IpcHandler {
        target: "diagnostics"

        function snapshot(): string {
            var screens = [];
            for (var screenIndex = 0; screenIndex < Quickshell.screens.length; screenIndex += 1) {
                screens.push(Quickshell.screens[screenIndex].name);
            }

            var workspaces = root.niriService.workspaces.map(function (workspace) {
                return {
                    id: workspace.id,
                    name: workspace.name || null,
                    output: workspace.output || null,
                    active: workspace.is_active === true,
                    focused: workspace.is_focused === true,
                    urgent: workspace.is_urgent === true
                };
            });
            var windows = root.niriService.windows.map(function (window) {
                return {
                    id: window.id,
                    appId: window.app_id || "",
                    workspaceId: window.workspace_id,
                    focused: window.is_focused === true,
                    urgent: window.is_urgent === true
                };
            });
            var channels = root.audioService.channels.map(function (channel) {
                return {
                    id: channel.id,
                    sinkPresent: channel.sink !== null,
                    bridgePresent: channel.bridge !== null,
                    observedDefault: channel.isObservedDefault === true,
                    outputName: channel.output ? channel.output.name : null,
                    outputPhysical: channel.output ? channel.output.isPhysical === true : false,
                    outputAvailable: channel.output ? channel.output.available === true : false,
                    outputCycleSafe: channel.output ? channel.output.isCycleSafe === true : false,
                    state: channel.status.state,
                    message: channel.status.message,
                    streamGroups: channel.groups.length
                };
            });
            var playbackStreams = root.audioService.playbackStreams.map(function (stream) {
                return {
                    id: stream.id,
                    serial: stream.serial,
                    channelId: stream.channelId,
                    persistentKey: stream.persistentKey
                };
            });

            return JSON.stringify({
                configName: root.configurationName,
                screens: screens,
                niri: {
                    connected: root.niriService.connected,
                    stale: root.niriService.stale,
                    generation: root.niriService.generation,
                    error: root.niriService.error,
                    workspaces: workspaces,
                    windows: windows
                },
                audio: {
                    ready: root.audioService.ready,
                    observedDefaultChannelId: root.audioService.observedDefaultChannelId,
                    defaultWarning: root.audioService.defaultWarning,
                    physicalOutputCount: root.audioService.physicalOutputs.length,
                    unroutedGroupCount: root.audioService.unroutedGroups.length,
                    pendingActionCount: root.audioActions.pendingOperationCount,
                    recentErrors: root.audioActions.recentErrors.length,
                    playbackStreams: playbackStreams,
                    channels: channels
                },
                mixerVisible: mixer.visible,
                launcher: {
                    opened: root.launcherController.opened,
                    pendingDesktopIds: root.launcherController.pendingDesktopIds,
                    failureDesktopId: root.launcherController.failureDesktopId,
                    failureMessage: root.launcherController.failureMessage
                },
                amoledVisible: amoled.active,
                polkit: {
                    enabled: root.polkitOverlay.enabled,
                    loaded: root.polkitOverlay.loaded,
                    registered: root.polkitOverlay.registered,
                    active: root.polkitOverlay.active,
                    error: root.polkitOverlay.error
                }
            });
        }
    }

    Bar.Bar {
        onMixerRequested: (anchorItem, screen, topInset) => mixer.toggleAt(anchorItem, screen, topInset)
        onTrayMenuOpening: mixer.dismissActiveChildPopup(false)
    }

    Dock.Dock {}

    Mixer.MixerPopup {
        id: mixer
    }

    Idle.AmoledOverlay {
        id: amoled
    }
}
