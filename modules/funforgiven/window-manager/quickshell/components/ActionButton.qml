pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".." as Shell

Item {
    id: root

    property string text: ""
    property string symbol: ""
    property color accent: Shell.Theme.systemAccent
    property string variant: "tonal"
    property bool compact: false
    property bool checked: false
    property bool checkable: false
    property bool keyboardPressed: false

    readonly property bool hovered: pointer.containsMouse
    readonly property bool pressed: pointer.pressed || keyboardPressed
    readonly property color backgroundColor: {
        if (!enabled)
            return "transparent";
        if (variant === "filled")
            return accent;
        if (variant === "danger")
            return Shell.Theme.errorSurface;
        if (checked)
            return Shell.Theme.selectedSurface;
        if (pressed)
            return Shell.Theme.pressedSurface;
        if (hovered)
            return Shell.Theme.hoverSurface;
        return variant === "text" ? "transparent" : Shell.Theme.elevatedSurface;
    }
    readonly property color contentColor: variant === "filled" ? Shell.Theme.accentText : (variant === "danger" ? Shell.Theme.errorText : Shell.Theme.primaryText)

    signal clicked

    implicitWidth: Math.max(compact ? Shell.Theme.controlCompactSize : 64, content.implicitWidth + Shell.Theme.spacingMedium * 2)
    implicitHeight: compact ? Shell.Theme.controlCompactSize : Shell.Theme.controlSize
    activeFocusOnTab: enabled
    scale: pressed ? Shell.Theme.pressedScale : 1
    opacity: enabled ? 1 : Shell.Theme.disabledOpacity

    Accessible.name: text
    Accessible.role: Accessible.Button
    Accessible.checkable: root.checkable
    Accessible.checked: root.checkable && root.checked
    Accessible.onPressAction: {
        if (root.enabled)
            root.clicked();
    }

    Keys.onPressed: event => {
        if (!root.enabled)
            return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.keyboardPressed = true;
            event.accepted = true;
        }
    }

    Keys.onReleased: event => {
        if (!root.enabled) {
            root.keyboardPressed = false;
            return;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (root.keyboardPressed)
                root.clicked();
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

    Behavior on opacity {
        NumberAnimation {
            duration: Shell.Theme.animationFast
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Shell.Theme.radiusPill
        color: root.backgroundColor
        border.width: root.checked && root.variant !== "filled" ? Shell.Theme.outlineWidth : 0
        border.color: root.accent

        Behavior on color {
            ColorAnimation {
                duration: Shell.Theme.animationFast
                easing.type: Shell.Theme.easingStandard
            }
        }
    }

    RowLayout {
        id: content

        anchors.centerIn: parent
        spacing: Shell.Theme.spacingSmall

        Text {
            visible: root.symbol.length > 0
            text: root.symbol
            color: root.contentColor
            font.family: Shell.Theme.sansFont
            font.pixelSize: Shell.Theme.iconMediumSize
            font.weight: Font.DemiBold
        }

        Text {
            visible: root.text.length > 0
            text: root.text
            color: root.contentColor
            font.family: Shell.Theme.sansFont
            font.pixelSize: Shell.Theme.labelFontSize
            font.weight: Font.DemiBold
        }
    }

    FocusRing {
        active: root.activeFocus
        accent: root.variant === "danger" ? Shell.Theme.error : root.accent
        ringRadius: Shell.Theme.radiusPill
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton
        onClicked: root.clicked()
    }
}
