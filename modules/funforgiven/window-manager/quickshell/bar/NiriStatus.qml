import QtQuick
import "../components" as Components
import "../services" as Services

Item {
    id: root

    readonly property bool failed: Services.NiriService.stale || Services.NiriService.configFailed || Services.NiriService.actionError.length > 0
    readonly property string failureMessage: Services.NiriService.actionError || (Services.NiriService.configFailed ? Services.NiriService.error || "Niri rejected the loaded configuration" : Services.NiriService.error || "Niri event state is reconnecting")

    visible: failed
    implicitWidth: statusChip.implicitWidth
    implicitHeight: statusChip.implicitHeight

    Accessible.name: "Niri desktop state failure"
    Accessible.description: failureMessage
    Accessible.role: Accessible.AlertMessage

    Components.StatusChip {
        id: statusChip

        anchors.fill: parent
        text: "Niri"
        tone: "error"
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Components.Tooltip {
        visible: pointer.containsMouse
        text: root.failureMessage
    }
}
