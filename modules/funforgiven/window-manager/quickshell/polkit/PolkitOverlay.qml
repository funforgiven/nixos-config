pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import ".." as Shell
import "../services" as Services
import "PolkitPlacement.js" as PolkitPlacement

Scope {
    id: root

    readonly property bool enabled: Shell.ShellConfig.nativePolkitEnabled
    readonly property bool loaded: nativeRuntime.active
    readonly property bool registered: nativeRuntime.item !== null && nativeRuntime.item.registered // qmllint disable missing-property
    readonly property bool active: nativeRuntime.item !== null && nativeRuntime.item.authenticationActive // qmllint disable missing-property
    readonly property string error: nativeRuntime.item !== null ? nativeRuntime.item.error : "" // qmllint disable missing-property

    LazyLoader {
        id: nativeRuntime

        active: root.enabled

        Scope {
            id: runtime

            property bool registrationDeadlineElapsed: false
            readonly property bool registered: agent.isRegistered
            readonly property bool authenticationActive: agent.isActive && agent.flow !== null // qmllint disable unresolved-type
            readonly property bool registrationFailed: !agent.isRegistered && registrationDeadlineElapsed
            readonly property string error: registrationFailed ? "The Quickshell polkit agent did not confirm registration." : ""
            readonly property var selectedScreen: PolkitPlacement.focusedScreen(Services.NiriService.connected && !Services.NiriService.stale ? Services.NiriService.workspaces : [], Quickshell.screens)

            function focusDialog() {
                if (runtime.authenticationActive) {
                    dialog.focusConversation();
                }
            }

            PolkitAgent {
                id: agent

                path: "/org/funforgiven/PolkitAgent"

                onAuthenticationRequestStarted: {
                    dialog.clearSensitiveInput();
                    dialog.prepareSensitiveInput();
                    Qt.callLater(runtime.focusDialog);
                }

                onFlowChanged: {
                    dialog.clearSensitiveInput();
                    if (agent.flow !== null) { // qmllint disable unresolved-type
                        dialog.prepareSensitiveInput();
                        Qt.callLater(runtime.focusDialog);
                    }
                }

                onIsRegisteredChanged: {
                    if (agent.isRegistered) {
                        runtime.registrationDeadlineElapsed = false;
                    }
                }
            }

            Timer {
                id: registrationWatchdog

                interval: 8000
                repeat: false
                running: !agent.isRegistered && !runtime.registrationDeadlineElapsed
                onTriggered: runtime.registrationDeadlineElapsed = true
            }

            PanelWindow { // qmllint disable uncreatable-type
                id: overlayWindow

                readonly property bool shouldShow: runtime.authenticationActive || runtime.registrationFailed

                screen: runtime.selectedScreen
                visible: shouldShow && screen !== null
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "funforgiven:polkit"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: runtime.authenticationActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                anchors {
                    left: true
                    right: true
                    top: true
                    bottom: true
                }

                mask: Region {
                    item: runtime.authenticationActive ? dimmer : dialog
                }

                onScreenChanged: Qt.callLater(runtime.focusDialog)
                onVisibleChanged: {
                    if (visible) {
                        Qt.callLater(runtime.focusDialog);
                    } else {
                        dialog.clearSensitiveInput();
                    }
                }

                Rectangle {
                    id: dimmer

                    anchors.fill: parent
                    color: runtime.authenticationActive ? Qt.rgba(0, 0, 0, 0.72) : "transparent"
                }

                PolkitDialog {
                    id: dialog

                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, Math.max(320, parent.width - Shell.Theme.spacingLarge * 2))
                    height: Math.min(implicitHeight, Math.max(240, parent.height - Shell.Theme.spacingLarge * 2))
                    flow: agent.flow // qmllint disable unresolved-type
                    registrationFailed: runtime.registrationFailed
                }
            }
        }
    }
}
