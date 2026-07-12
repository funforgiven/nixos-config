import QtQuick
import QtQuick.Layouts
import ".." as Shell
import "../components" as Components
import "../services" as Services

ColumnLayout {
    id: root

    required property var channel
    required property color accent
    readonly property var bridgeAudio: channel && channel.bridge ? channel.bridge.audio : null
    readonly property real value: bridgeAudio ? Math.max(0, Math.min(1, Number(bridgeAudio.volume))) : 0
    readonly property bool available: bridgeAudio !== null

    spacing: Shell.Theme.spacingXSmall

    RowLayout {
        Layout.fillWidth: true

        Item {
            Layout.fillWidth: true
        }

        Text {
            text: root.available ? Math.round(gainSlider.presentedValue * 100) + "%" : "Unavailable"
            color: root.available ? Shell.Theme.primaryText : Shell.Theme.errorText
            font.family: Shell.Theme.monoFont
            font.pixelSize: Shell.Theme.labelFontSize
            font.weight: Font.DemiBold
        }
    }

    Components.MaterialSlider {
        id: gainSlider

        Layout.fillWidth: true
        value: root.value
        accent: root.accent
        enabled: root.available
        accessibleName: root.channel.label + " channel volume"
        onValueRequested: value => Services.AudioActions.setChannelVolume(root.channel.id, value)
    }
}
