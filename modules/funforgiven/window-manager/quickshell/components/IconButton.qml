import QtQuick
import Quickshell.Widgets
import ".." as Shell

Item {
    id: root

    property string iconSource: ""
    property string label: ""
    property string accessibleName: label
    property string tooltipText: accessibleName
    property color accent: Shell.Theme.systemAccent
    property color iconColor: Shell.Theme.primaryText
    property bool tintIcon: false
    property bool checked: false
    property bool attention: false
    property bool hovered: pointer.containsMouse
    property int iconSize: Shell.Theme.iconMediumSize
    property bool keyboardPressed: false

    readonly property bool pressed: pointer.pressed || keyboardPressed
    readonly property color checkedColor: Qt.rgba(accent.r, accent.g, accent.b, pressed ? Shell.Theme.pressedOverlayOpacity : Shell.Theme.selectedOverlayOpacity)
    readonly property color backgroundColor: {
        if (!enabled)
            return "transparent";
        if (checked)
            return checkedColor;
        if (pressed)
            return Shell.Theme.pressedSurface;
        if (hovered)
            return Shell.Theme.hoverSurface;
        return attention ? Qt.rgba(Shell.Theme.error.r, Shell.Theme.error.g, Shell.Theme.error.b, Shell.Theme.subtleOverlayOpacity) : "transparent";
    }

    signal clicked(int button)
    signal wheel(int delta, bool horizontal)

    implicitWidth: Shell.Theme.controlCompactSize
    implicitHeight: Shell.Theme.controlCompactSize
    activeFocusOnTab: true
    scale: pressed ? Shell.Theme.pressedScale : 1

    Accessible.name: accessibleName
    Accessible.role: Accessible.Button
    Accessible.onPressAction: {
        if (root.enabled)
            root.clicked(Qt.LeftButton);
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.keyboardPressed = true;
            event.accepted = true;
        }
    }

    Keys.onReleased: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (root.keyboardPressed)
                root.clicked(Qt.LeftButton);
            root.keyboardPressed = false;
            event.accepted = true;
        }
    }

    onEnabledChanged: {
        if (!enabled)
            keyboardPressed = false;
    }
    onActiveFocusChanged: {
        if (!activeFocus)
            keyboardPressed = false;
    }

    Behavior on scale {
        NumberAnimation {
            duration: Shell.Theme.animationFast
            easing.type: Shell.Theme.easingStandard
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
        radius: Shell.Theme.radiusSmall
        border.color: root.attention ? Shell.Theme.error : (root.checked ? root.accent : "transparent")
        border.width: root.attention || root.checked ? Shell.Theme.outlineWidth : 0

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

    IconImage {
        visible: root.iconSource.length > 0 && !root.tintIcon
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: root.tintIcon ? "" : root.iconSource
        mipmap: true
        opacity: root.enabled ? 1 : Shell.Theme.disabledOpacity

        Behavior on opacity {
            NumberAnimation {
                duration: Shell.Theme.animationFast
            }
        }
    }

    TintedIcon {
        visible: root.iconSource.length > 0 && root.tintIcon
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: root.tintIcon ? root.iconSource : ""
        tint: root.iconColor
        opacity: root.enabled ? 1 : Shell.Theme.disabledOpacity

        Behavior on opacity {
            NumberAnimation {
                duration: Shell.Theme.animationFast
            }
        }
    }

    Text {
        visible: root.iconSource.length === 0
        anchors.centerIn: parent
        color: root.enabled ? Shell.Theme.primaryText : Shell.Theme.secondaryText
        text: root.label
        font.family: Shell.Theme.sansFont
        font.pixelSize: Shell.Theme.labelFontSize
        font.weight: Font.DemiBold
        opacity: root.enabled ? 1 : Shell.Theme.disabledOpacity
    }

    FocusRing {
        active: root.activeFocus
        accent: root.accent
        ringRadius: Shell.Theme.radiusSmall
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked(mouse.button)
        onWheel: wheel => {
            const horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y);
            const angled = horizontal ? wheel.angleDelta.x : wheel.angleDelta.y;
            const pixel = horizontal ? wheel.pixelDelta.x : wheel.pixelDelta.y;
            root.wheel(angled !== 0 ? angled : pixel, horizontal);
            wheel.accepted = true;
        }
    }

    Tooltip {
        visible: root.hovered && root.tooltipText.length > 0
        text: root.tooltipText
    }
}
