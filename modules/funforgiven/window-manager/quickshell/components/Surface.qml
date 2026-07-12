import QtQuick
import ".." as Shell

Rectangle {
    id: root

    property bool elevated: false
    property bool raised: false
    property bool interactive: false
    property bool hovered: false
    property bool pressed: false
    property bool selected: false
    property color accent: Shell.Theme.systemAccent
    property color surfaceColor: raised ? Shell.Theme.raisedSurface : (elevated ? Shell.Theme.elevatedSurface : Shell.Theme.baseSurface)
    property color hoverColor: Shell.Theme.hoverSurface
    property color pressedColor: Shell.Theme.pressedSurface
    property color selectedColor: Shell.Theme.selectedSurface
    property color outlineColor: Shell.Theme.outline
    property int outlineWidth: Shell.Theme.outlineWidth

    readonly property color resolvedSurfaceColor: interactive && pressed ? pressedColor : (selected ? selectedColor : (interactive && hovered ? hoverColor : surfaceColor))
    readonly property color resolvedOutlineColor: activeFocus || selected ? accent : outlineColor
    readonly property int resolvedOutlineWidth: activeFocus ? Shell.Theme.focusRingWidth : outlineWidth

    color: resolvedSurfaceColor
    radius: Shell.Theme.radiusMedium
    border.color: resolvedOutlineColor
    border.width: resolvedOutlineWidth
    antialiasing: true

    Behavior on color {
        ColorAnimation {
            duration: Shell.Theme.animationFast
            easing.type: Shell.Theme.easingStandard
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: Shell.Theme.animationFast
            easing.type: Shell.Theme.easingStandard
        }
    }
}
