import QtQuick
import ".." as Shell

Rectangle {
    id: root

    property bool active: false
    property color accent: Shell.Theme.systemAccent
    property int ringRadius: Shell.Theme.radiusSmall

    anchors.fill: parent
    anchors.margins: -2
    color: "transparent"
    radius: ringRadius
    border.color: accent
    border.width: 2
    opacity: active ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: Shell.Theme.animationFast
        }
    }
}
