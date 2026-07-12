pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property bool active: false

    IpcHandler {
        target: "amoled"

        function activate(): void {
            root.active = true;
        }

        function deactivate(): void {
            root.active = false;
        }

        function isVisible(): bool {
            return root.active;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow { // qmllint disable uncreatable-type
            required property var modelData

            screen: modelData
            visible: root.active
            color: "#000000"
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}

            anchors {
                top: true
                right: true
                bottom: true
                left: true
            }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "funforgiven-amoled"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        }
    }
}
