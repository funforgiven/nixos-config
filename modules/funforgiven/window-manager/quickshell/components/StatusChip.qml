import QtQuick
import ".." as Shell

Rectangle {
    id: root

    property string text: ""
    property color accent: Shell.Theme.systemAccent
    property string tone: "accent"

    readonly property color resolvedAccent: tone === "error" ? Shell.Theme.error : (tone === "warning" ? Shell.Theme.warning : (tone === "success" ? Shell.Theme.success : accent))
    readonly property color resolvedSurface: tone === "error" ? Shell.Theme.errorSurface : (tone === "warning" ? Shell.Theme.warningSurface : (tone === "success" ? Shell.Theme.successSurface : Qt.rgba(resolvedAccent.r, resolvedAccent.g, resolvedAccent.b, Shell.Theme.selectedOverlayOpacity)))

    implicitWidth: label.implicitWidth + Shell.Theme.spacingMedium * 2
    implicitHeight: 28
    radius: Shell.Theme.radiusPill
    color: resolvedSurface

    Text {
        id: label

        anchors.centerIn: parent
        text: root.text
        color: Shell.Theme.primaryText
        font.family: Shell.Theme.sansFont
        font.pixelSize: Shell.Theme.captionFontSize
        font.weight: Font.DemiBold
    }
}
