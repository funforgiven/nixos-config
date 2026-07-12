pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import ".." as Shell
import "../components" as Components

Scope {
    id: root

    signal mixerRequested(var anchorItem, var screen, real topInset)
    signal trayMenuOpening

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: barWindow

            required property var modelData

            screen: modelData
            implicitHeight: 56
            color: "transparent"
            anchors {
                left: true
                right: true
                top: true
            }
            exclusiveZone: implicitHeight
            focusable: false
            aboveWindows: true
            WlrLayershell.namespace: "funforgiven:bar"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Components.Surface {
                id: leftIsland

                readonly property real desiredWidth: workspaceTasks.implicitWidth + Shell.Theme.spacingXSmall * 2
                readonly property real availableWidth: Math.max(Shell.Theme.controlLargeSize, rightIsland.x - anchors.leftMargin - Shell.Theme.spacingMedium)

                anchors.left: parent.left
                anchors.leftMargin: Shell.Theme.spacingMedium
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(Math.max(desiredWidth, Shell.Theme.controlLargeSize), availableWidth)
                height: Shell.Theme.controlSize
                elevated: true
                radius: Shell.Theme.radiusMedium

                WorkspaceStrip {
                    id: workspaceTasks

                    anchors.fill: parent
                    anchors.margins: Shell.Theme.spacingXSmall
                    outputName: barWindow.screen.name
                }
            }

            Components.Surface {
                id: rightIsland
                anchors.right: parent.right
                anchors.rightMargin: Shell.Theme.spacingMedium
                anchors.verticalCenter: parent.verticalCenter
                width: implicitWidth
                height: Shell.Theme.controlSize
                implicitWidth: statusArea.implicitWidth + Shell.Theme.spacingXSmall * 2
                elevated: true
                radius: Shell.Theme.radiusMedium

                Row {
                    id: statusArea

                    anchors.centerIn: parent
                    height: Shell.Theme.controlCompactSize
                    spacing: Shell.Theme.spacingXSmall

                    NiriStatus {
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Tray {
                        id: tray

                        height: parent.height
                        width: implicitWidth
                        parentWindow: barWindow
                        onMenuOpening: root.trayMenuOpening()
                    }

                    MixerButton {
                        id: mixerButton

                        height: parent.height
                        width: implicitWidth
                        onRequested: {
                            tray.dismissMenu();
                            root.mixerRequested(mixerButton, barWindow.screen, barWindow.height);
                        }
                    }

                    Clock {
                        height: parent.height
                        width: implicitWidth
                    }

                    SessionControls {
                        height: parent.height
                        width: implicitWidth
                    }
                }
            }
        }
    }
}
