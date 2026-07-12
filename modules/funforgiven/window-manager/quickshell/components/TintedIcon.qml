import QtQuick
import QtQuick.Controls as Controls
import ".." as Shell

// Quickshell 0.3's IconImage cannot recolor symbolic theme assets. Qt Controls'
// public icon pipeline applies a SourceIn tint while preserving the source's
// exact alpha mask, geometry, and padding.
Controls.ToolButton {
    id: root

    property url source
    property color tint: Shell.Theme.primaryText

    implicitWidth: Shell.Theme.iconMediumSize
    implicitHeight: Shell.Theme.iconMediumSize
    display: Controls.AbstractButton.IconOnly
    padding: 0
    spacing: 0
    background: null
    hoverEnabled: false
    focusPolicy: Qt.NoFocus
    activeFocusOnTab: false

    icon.source: root.source
    icon.width: Math.max(1, root.width)
    icon.height: Math.max(1, root.height)
    icon.color: root.tint

    Accessible.ignored: true
}
