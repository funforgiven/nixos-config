import QtQuick
import QtQuick.Layouts
import ".." as Shell

Rectangle {
    id: root

    property string title: ""
    property string detail: ""
    property url iconSource: ""
    property color accent: Shell.Theme.systemAccent

    implicitWidth: 280
    implicitHeight: 64
    radius: Shell.Theme.radiusMedium
    color: Shell.Theme.raisedSurface
    border.width: 2
    border.color: accent
    opacity: 0.96

    RowLayout {
        anchors.fill: parent
        anchors.margins: Shell.Theme.spacingMedium
        spacing: Shell.Theme.spacingMedium

        AppIcon {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            iconSize: 32
            source: root.iconSource
            accessibleName: root.title
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Shell.Theme.primaryText
                elide: Text.ElideRight
                font.family: Shell.Theme.sansFont
                font.pixelSize: Shell.Theme.bodyFontSize
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                visible: root.detail.length > 0
                text: root.detail
                color: Shell.Theme.secondaryText
                elide: Text.ElideRight
                font.family: Shell.Theme.sansFont
                font.pixelSize: Shell.Theme.captionFontSize
            }
        }
    }
}
