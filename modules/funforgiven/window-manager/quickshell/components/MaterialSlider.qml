pragma ComponentBehavior: Bound

// Portions adapted from Avenge Media's MIT-licensed slider at commit
// d82d86df5cb932fc275dcf30c35cd72705a21065. See THIRD_PARTY_NOTICES.md.

import QtQuick
import ".." as Shell

Item {
    id: root

    property real value: 0
    property real minimum: 0
    property real maximum: 1
    property real stepSize: 0.01
    property color accent: Shell.Theme.systemAccent
    property color trackColor: Shell.Theme.outline
    property string accessibleName: "Value"
    property real dragValue: value

    readonly property real clampedValue: clamp(value)
    readonly property real presentedValue: pointer.pressed ? dragValue : clampedValue
    readonly property real visualPosition: maximum <= minimum ? 0 : (presentedValue - minimum) / (maximum - minimum)
    readonly property bool hovered: pointer.containsMouse

    signal valueRequested(real value)

    function clamp(candidate) {
        var numeric = Number(candidate);
        return isFinite(numeric) ? Math.max(minimum, Math.min(maximum, numeric)) : minimum;
    }

    function snapped(candidate) {
        var bounded = clamp(candidate);
        if (stepSize <= 0)
            return bounded;
        return clamp(minimum + Math.round((bounded - minimum) / stepSize) * stepSize);
    }

    function request(candidate) {
        if (!isFinite(Number(candidate)))
            return false;
        var next = snapped(candidate);
        var previous = pointer.pressed ? dragValue : clampedValue;
        if (Math.abs(next - previous) < Math.max(0.000001, stepSize / 100))
            return false;
        dragValue = next;
        valueRequested(next);
        return true;
    }

    function requestFromX(pointerX) {
        var localX = pointer.mapToItem(track, pointerX, 0).x;
        request(minimum + clampRatio(localX / Math.max(1, track.width)) * (maximum - minimum));
    }

    function clampRatio(candidate) {
        return Math.max(0, Math.min(1, candidate));
    }

    implicitHeight: Shell.Theme.controlLargeSize
    activeFocusOnTab: enabled

    Accessible.name: accessibleName
    Accessible.description: Math.round(presentedValue * 100) + "%"
    Accessible.role: Accessible.Slider
    Accessible.onIncreaseAction: request(presentedValue + stepSize)
    Accessible.onDecreaseAction: request(presentedValue - stepSize)

    Keys.onPressed: event => {
        if (!root.enabled)
            return;
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) {
            root.request(root.presentedValue - root.stepSize);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) {
            root.request(root.presentedValue + root.stepSize);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageDown) {
            root.request(root.presentedValue - root.stepSize * 10);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            root.request(root.presentedValue + root.stepSize * 10);
            event.accepted = true;
        } else if (event.key === Qt.Key_Home) {
            root.request(root.minimum);
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.request(root.maximum);
            event.accepted = true;
        }
    }

    Rectangle {
        id: track

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 12
        radius: Shell.Theme.radiusPill
        color: root.trackColor
        opacity: root.enabled ? 1 : Shell.Theme.disabledOpacity

        Rectangle {
            width: Math.max(0, parent.width * root.visualPosition - handle.width / 2 - 3)
            height: parent.height
            radius: Shell.Theme.radiusPill
            color: root.accent

            Behavior on width {
                enabled: !pointer.pressed
                NumberAnimation {
                    duration: Shell.Theme.animationFast
                    easing.type: Shell.Theme.easingStandard
                }
            }
        }

        Rectangle {
            id: handle

            x: Math.max(0, Math.min(parent.width - width, (parent.width - width) * root.visualPosition))
            anchors.verticalCenter: parent.verticalCenter
            width: root.hovered || pointer.pressed || root.activeFocus ? 8 : 6
            height: pointer.pressed ? 28 : 24
            radius: Shell.Theme.radiusPill
            color: root.accent
            border.width: 2
            border.color: Shell.Theme.baseSurface

            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 18
                height: parent.height + 18
                radius: Shell.Theme.radiusPill
                color: "transparent"
                border.width: root.activeFocus ? Shell.Theme.focusRingWidth : 0
                border.color: root.accent
                opacity: 0.7
            }

            Behavior on x {
                enabled: !pointer.pressed
                NumberAnimation {
                    duration: Shell.Theme.animationFast
                    easing.type: Shell.Theme.easingStandard
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: Shell.Theme.animationFast
                    easing.type: Shell.Theme.easingStandard
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: Shell.Theme.animationFast
                    easing.type: Shell.Theme.easingStandard
                }
            }
        }
    }

    Item {
        id: pointerGrabTarget

        width: 1
        height: 1
        opacity: 0
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        preventStealing: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton
        drag.target: pointerGrabTarget
        drag.axis: Drag.XAxis
        drag.threshold: 0
        drag.minimumX: -root.width
        drag.maximumX: root.width
        drag.smoothed: false

        onPressed: mouse => {
            mouse.accepted = true;
            root.forceActiveFocus();
            root.dragValue = root.clampedValue;
            root.requestFromX(mouse.x);
        }

        onPositionChanged: mouse => {
            if (pressed)
                root.requestFromX(mouse.x);
        }

        onReleased: pointerGrabTarget.x = 0
        onCanceled: {
            pointerGrabTarget.x = 0;
            root.dragValue = root.clampedValue;
        }

        onWheel: event => {
            var delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
            if (delta === 0)
                delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.pixelDelta.x;
            if (delta === 0) {
                event.accepted = false;
                return;
            }
            root.request(root.presentedValue + Math.sign(delta) * root.stepSize);
            event.accepted = true;
        }
    }
}
