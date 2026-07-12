import QtQuick
import Quickshell
import ".." as Shell
import "../components" as Components

Item {
    id: root

    implicitWidth: clockText.implicitWidth + Shell.Theme.spacingMedium * 2
    implicitHeight: Shell.Theme.controlCompactSize

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Text {
        id: clockText

        anchors.centerIn: parent
        color: Shell.Theme.primaryText
        text: Qt.formatDateTime(clock.date, "ddd d MMM · HH:mm")
        font.family: Shell.Theme.sansFont
        font.pixelSize: Shell.Theme.labelFontSize
        font.weight: Font.DemiBold
    }

    MouseArea {
        id: clockPointer

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Components.Tooltip {
        visible: clockPointer.containsMouse
        text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy · HH:mm")
    }
}
