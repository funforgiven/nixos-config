pragma ComponentBehavior: Bound

import QtQuick
import ".." as Shell
import "../components" as Components

Item {
    id: root

    required property var appGroup
    property string errorText: ""
    property bool pending: false

    signal activated

    readonly property bool running: appGroup.windows.length > 0
    readonly property bool focused: appGroup.focused === true
    readonly property bool urgent: appGroup.urgent === true
    readonly property bool hovered: dockPointer.containsMouse
    readonly property bool pressed: !pending && dockPointer.pressed
    readonly property int instanceCount: appGroup.windows.length
    readonly property color stateColor: errorText.length > 0 || urgent ? Shell.Theme.error : Shell.Theme.systemAccent
    readonly property color tileColor: errorText.length > 0 || urgent ? Shell.Theme.errorSurface : (focused ? Shell.Theme.selectedSurface : (pressed ? Shell.Theme.pressedSurface : (hovered ? Shell.Theme.hoverSurface : "transparent")))

    implicitWidth: 56
    implicitHeight: 56

    Accessible.name: appGroup.displayName
    Accessible.description: errorText.length > 0 ? errorText : (pending ? "Launch pending" : (running ? `${instanceCount} running window${instanceCount === 1 ? "" : "s"}` : "Not running"))
    Accessible.role: Accessible.Button
    Accessible.onPressAction: root.activateIfReady()

    function activateIfReady() {
        if (!root.pending)
            root.activated();
    }

    Item {
        id: visual

        anchors.fill: parent
        anchors.margins: 1
        scale: root.pressed ? Shell.Theme.pressedScale : 1
        transformOrigin: Item.Center

        Behavior on scale {
            NumberAnimation {
                duration: Shell.Theme.animationFast
                easing.type: Shell.Theme.easingStandard
            }
        }

        Rectangle {
            anchors.fill: parent
            color: root.tileColor
            radius: Shell.Theme.radiusMedium
            border.color: root.errorText.length > 0 || root.urgent || root.focused ? root.stateColor : "transparent"
            border.width: root.errorText.length > 0 || root.urgent || root.focused ? Shell.Theme.outlineWidth : 0

            Behavior on color {
                ColorAnimation {
                    duration: Shell.Theme.animationFast
                    easing.type: Shell.Theme.easingStandard
                }
            }
        }

        Components.AppIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 7
            width: 38
            height: 38
            iconSize: 38
            source: root.appGroup.iconPath
            accessibleName: root.appGroup.displayName
        }

        Rectangle {
            visible: root.running
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            width: root.focused ? 22 : 7
            height: 3
            radius: Shell.Theme.radiusPill
            color: root.stateColor

            Behavior on width {
                NumberAnimation {
                    duration: Shell.Theme.animationFast
                    easing.type: Shell.Theme.easingStandard
                }
            }
        }

        Row {
            visible: root.instanceCount > 1
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 5
            height: 12
            spacing: 2

            Repeater {
                model: Math.min(root.instanceCount, 3)

                Rectangle {
                    required property int index

                    y: 4
                    width: 4
                    height: 4
                    radius: Shell.Theme.radiusPill
                    color: root.urgent ? Shell.Theme.error : Shell.Theme.primaryText
                    opacity: 0.88 - index * 0.18
                }
            }

            Text {
                visible: root.instanceCount > 3
                height: 12
                text: `+${root.instanceCount - 3}`
                color: Shell.Theme.secondaryText
                verticalAlignment: Text.AlignVCenter
                font.family: Shell.Theme.monoFont
                font.pixelSize: Shell.Theme.captionFontSize
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            visible: root.errorText.length > 0 || root.urgent
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 5
            width: 7
            height: 7
            radius: Shell.Theme.radiusPill
            color: root.stateColor
        }
    }

    MouseArea {
        id: dockPointer

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activateIfReady()
    }

    Components.Tooltip {
        visible: dockPointer.containsMouse
        text: {
            if (root.errorText.length > 0)
                return `${root.appGroup.displayName}\n${root.errorText}`;
            if (root.pending)
                return `${root.appGroup.displayName}\nLaunching…`;
            if (!root.running)
                return `${root.appGroup.displayName}\nClick to launch`;
            if (root.appGroup.windows.length === 1)
                return `${root.appGroup.displayName}\n${root.appGroup.windows[0].title || "Running"}`;
            return `${root.appGroup.displayName}\n${root.appGroup.windows.length} windows · click to cycle`;
        }
    }
}
