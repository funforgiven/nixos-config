pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".." as Shell
import "../components" as Components
import "../services" as Services
import "DragModel.js" as DragModel

Rectangle {
    id: root

    required property var group
    required property color accent
    property string sourceChannelId: ""
    property var dragSession: null
    property bool unrouted: false
    property bool dragCanceled: false
    property int activeDragToken: 0
    property string activeDragKey: ""
    readonly property string dragKey: "group:" + String(group.key)
    readonly property bool dragging: dragSession !== null && dragSession.active && activeDragToken > 0 && dragSession.currentToken === activeDragToken
    readonly property var dragPayload: DragModel.groupPayload(root.group, root.sourceChannelId)
    readonly property int pendingCount: group.streams.filter(function (stream) {
        return Services.AudioActions.pendingStreams[String(stream.id) + ":" + String(stream.serial)];
    }).length
    readonly property var errors: group.streams.map(function (stream) {
        return Services.AudioActions.streamErrors[String(stream.id) + ":" + String(stream.serial)] || "";
    }).filter(function (message) {
        return message !== "";
    })
    readonly property string statusText: {
        if (errors.length > 0)
            return errors.join(" · ");
        if (pendingCount > 0)
            return pendingCount === group.count ? "Moving…" : pendingCount + " of " + group.count + " moving";
        if (unrouted)
            return "Unrouted";
        return group.count > 1 ? group.count + " streams" : "";
    }
    readonly property color statusColor: errors.length > 0 ? Shell.Theme.errorText : (pendingCount > 0 || unrouted ? Shell.Theme.warningText : Shell.Theme.secondaryText)

    function moveAdjacent(direction) {
        if (root.pendingCount > 0)
            return false;
        var destination = DragModel.adjacentChannelId(Shell.ShellConfig.audioChannels, root.sourceChannelId, direction, function (channelId) {
            var channel = Services.AudioService.channel(channelId);
            return channel !== null && channel.sink !== null;
        });
        return destination.length > 0 && Services.AudioActions.moveGroup(root.group.key, destination);
    }

    Component.onDestruction: {
        if (dragSession !== null && activeDragToken > 0)
            dragSession.cancel(activeDragToken);
    }

    implicitHeight: content.implicitHeight + Shell.Theme.spacingMedium * 2
    radius: Shell.Theme.radiusMedium
    color: dragging ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, Shell.Theme.subtleOverlayOpacity) : Shell.Theme.raisedSurface
    border.width: Shell.Theme.outlineWidth
    border.color: errors.length > 0 ? Shell.Theme.error : (unrouted ? Shell.Theme.warning : Shell.Theme.outline)
    opacity: dragging ? 0.68 : 1

    Behavior on opacity {
        NumberAnimation {
            duration: Shell.Theme.animationFast
            easing.type: Shell.Theme.easingStandard
        }
    }

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Shell.Theme.spacingMedium
        spacing: Shell.Theme.spacingSmall

        RowLayout {
            Layout.fillWidth: true
            spacing: Shell.Theme.spacingSmall

            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                radius: Shell.Theme.radiusMedium
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, Shell.Theme.selectedOverlayOpacity)

                Components.AppIcon {
                    anchors.fill: parent
                    anchors.margins: 6
                    iconSize: 32
                    source: root.group.iconPath
                    accessibleName: root.group.displayName
                    Accessible.ignored: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: root.group.displayName
                    color: Shell.Theme.primaryText
                    elide: Text.ElideRight
                    font.family: Shell.Theme.sansFont
                    font.pixelSize: Shell.Theme.bodyFontSize
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.statusText.length > 0
                    text: root.statusText
                    color: root.statusColor
                    elide: Text.ElideRight
                    font.family: Shell.Theme.sansFont
                    font.pixelSize: Shell.Theme.captionFontSize
                }
            }

            Rectangle {
                id: groupGrip

                Layout.preferredWidth: Shell.Theme.controlCompactSize
                Layout.preferredHeight: Shell.Theme.controlCompactSize
                radius: Shell.Theme.radiusSmall
                color: groupDrag.active ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, Shell.Theme.pressedOverlayOpacity) : (groupGripHover.hovered ? Shell.Theme.hoverSurface : "transparent")
                opacity: root.pendingCount === 0 ? 1 : Shell.Theme.disabledOpacity
                activeFocusOnTab: enabled
                enabled: root.pendingCount === 0

                Accessible.name: "Audio channel for " + root.group.displayName
                Accessible.description: "Drag to another channel, or use Left and Right arrow keys"
                Accessible.role: Accessible.Slider
                Accessible.onIncreaseAction: root.moveAdjacent(1)
                Accessible.onDecreaseAction: root.moveAdjacent(-1)

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left) {
                        root.moveAdjacent(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right) {
                        root.moveAdjacent(1);
                        event.accepted = true;
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Shell.Theme.animationFast
                        easing.type: Shell.Theme.easingStandard
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "⠿"
                    color: groupDrag.active ? Shell.Theme.primaryText : Shell.Theme.secondaryText
                    font.pixelSize: Shell.Theme.iconMediumSize
                    Accessible.ignored: true
                }

                HoverHandler {
                    id: groupGripHover

                    cursorShape: groupDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                }

                Components.FocusRing {
                    active: groupGrip.activeFocus
                    accent: root.accent
                    ringRadius: Shell.Theme.radiusSmall
                }

                DragHandler {
                    id: groupDrag

                    enabled: root.dragSession !== null && root.pendingCount === 0 && (!root.dragSession.active || root.dragSession.sourceKey === root.activeDragKey)
                    target: null
                    margin: Shell.Theme.spacingXSmall
                    dragThreshold: 4
                    grabPermissions: PointerHandler.CanTakeOverFromAnything

                    onActiveChanged: {
                        if (active) {
                            root.dragCanceled = false;
                            root.activeDragKey = root.dragKey;
                            root.activeDragToken = root.dragSession.begin(root, groupGrip, centroid.position.x, centroid.position.y, root.dragPayload, root.group.displayName, root.group.count > 1 ? root.group.count + " streams" : "1 stream", root.group.iconPath, root.accent, root.activeDragKey);
                            if (root.activeDragToken === 0) {
                                root.dragCanceled = true;
                                root.activeDragKey = "";
                            }
                        } else {
                            var completedToken = root.activeDragToken;
                            Qt.callLater(function () {
                                if (groupDrag.active || completedToken === 0 || root.activeDragToken !== completedToken)
                                    return;
                                if (root.dragSession)
                                    root.dragSession.finish(completedToken, root.dragCanceled);
                                root.activeDragToken = 0;
                                root.activeDragKey = "";
                                root.dragCanceled = false;
                            });
                        }
                    }

                    onActiveTranslationChanged: {
                        if (root.activeDragToken > 0 && root.dragSession)
                            root.dragSession.updatePointer(root.activeDragToken, groupGrip, centroid.position.x, centroid.position.y);
                    }

                    onCanceled: root.dragCanceled = true
                }
            }
        }

        StreamChildren {
            Layout.fillWidth: true
            visible: root.group.count > 1 || root.unrouted
            streams: root.group.streams
            accent: root.accent
            sourceChannelId: root.sourceChannelId
            dragSession: root.dragSession
        }
    }
}
