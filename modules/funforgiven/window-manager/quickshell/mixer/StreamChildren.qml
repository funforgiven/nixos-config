pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".." as Shell
import "../components" as Components
import "../components/StableKeys.js" as StableKeys
import "../services" as Services
import "DragModel.js" as DragModel

ColumnLayout {
    id: root

    required property var streams
    required property color accent
    property string sourceChannelId: ""
    property var dragSession: null
    property var streamKeys: []
    spacing: Shell.Theme.spacingSmall

    function streamKey(stream) {
        return String(stream.id) + ":" + String(stream.serial);
    }

    function streamForKey(key) {
        return StableKeys.find(root.streams, key, function (stream) {
            return root.streamKey(stream);
        });
    }

    function missingStream(key) {
        var parts = String(key).split(":");
        return {
            id: parts[0] || "missing",
            serial: parts.slice(1).join(":") || "missing",
            canonicalId: "",
            persistentKey: "",
            childLabel: "",
            iconPath: "",
            routingState: "unrouted"
        };
    }

    function syncStreamKeys() {
        var next = StableKeys.reconcile(root.streamKeys, root.streams, function (stream) {
            return root.streamKey(stream);
        });
        if (next !== root.streamKeys)
            root.streamKeys = next;
    }

    Repeater {
        model: root.streamKeys

        delegate: Rectangle {
            id: childRow

            required property string modelData
            readonly property var liveStream: root.streamForKey(modelData)
            readonly property var stream: liveStream || root.missingStream(modelData)
            readonly property string stateKey: modelData
            readonly property string dragKey: "stream:" + stateKey
            readonly property var pending: Services.AudioActions.pendingStreams[stateKey] || null
            readonly property string error: Services.AudioActions.streamErrors[stateKey] || ""
            readonly property bool dragging: root.dragSession !== null && root.dragSession.active && activeDragToken > 0 && root.dragSession.currentToken === activeDragToken
            property bool dragCanceled: false
            property int activeDragToken: 0
            property string activeDragKey: ""
            readonly property var dragPayload: DragModel.singleStreamPayload(stream, root.sourceChannelId)
            readonly property string statusText: error || (pending ? "Moving…" : (stream.routingState === "routed" ? "" : stream.routingState))
            readonly property color statusColor: error ? Shell.Theme.errorText : (pending ? Shell.Theme.warningText : (stream.routingState !== "routed" ? Shell.Theme.errorText : Shell.Theme.secondaryText))

            function moveAdjacent(direction) {
                if (childRow.pending !== null)
                    return false;
                var destination = DragModel.adjacentChannelId(Shell.ShellConfig.audioChannels, root.sourceChannelId, direction, function (channelId) {
                    var channel = Services.AudioService.channel(channelId);
                    return channel !== null && channel.sink !== null;
                });
                return destination.length > 0 && Services.AudioActions.moveStream(childRow.stream, destination);
            }

            Component.onDestruction: {
                if (root.dragSession !== null && activeDragToken > 0)
                    root.dragSession.cancel(activeDragToken);
            }

            Layout.fillWidth: true
            visible: liveStream !== null
            implicitHeight: childContent.implicitHeight + Shell.Theme.spacingSmall * 2
            radius: Shell.Theme.radiusSmall
            color: dragging ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, Shell.Theme.subtleOverlayOpacity) : Shell.Theme.baseSurface
            border.width: Shell.Theme.outlineWidth
            border.color: error ? Shell.Theme.error : Shell.Theme.outline
            opacity: dragging ? 0.68 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Shell.Theme.animationFast
                    easing.type: Shell.Theme.easingStandard
                }
            }

            ColumnLayout {
                id: childContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Shell.Theme.spacingSmall
                spacing: Shell.Theme.spacingSmall

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Shell.Theme.spacingSmall

                    Rectangle {
                        id: childGrip

                        Layout.preferredWidth: Shell.Theme.controlCompactSize
                        Layout.preferredHeight: Shell.Theme.controlCompactSize
                        radius: Shell.Theme.radiusSmall
                        color: childDrag.active ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, Shell.Theme.pressedOverlayOpacity) : (childGripHover.hovered ? Shell.Theme.hoverSurface : "transparent")
                        opacity: childRow.pending === null ? 1 : Shell.Theme.disabledOpacity
                        activeFocusOnTab: enabled
                        enabled: childRow.pending === null

                        Accessible.name: "Audio channel for " + childRow.stream.childLabel
                        Accessible.description: "Drag to another channel, or use Left and Right arrow keys"
                        Accessible.role: Accessible.Slider
                        Accessible.onIncreaseAction: childRow.moveAdjacent(1)
                        Accessible.onDecreaseAction: childRow.moveAdjacent(-1)

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Left) {
                                childRow.moveAdjacent(-1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Right) {
                                childRow.moveAdjacent(1);
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
                            color: childDrag.active ? Shell.Theme.primaryText : Shell.Theme.secondaryText
                            font.pixelSize: Shell.Theme.iconSmallSize
                            Accessible.ignored: true
                        }

                        HoverHandler {
                            id: childGripHover

                            cursorShape: childDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        }

                        Components.FocusRing {
                            active: childGrip.activeFocus
                            accent: root.accent
                            ringRadius: Shell.Theme.radiusSmall
                        }

                        DragHandler {
                            id: childDrag

                            enabled: root.dragSession !== null && childRow.pending === null && (!root.dragSession.active || root.dragSession.sourceKey === childRow.activeDragKey)
                            target: null
                            margin: Shell.Theme.spacingXSmall
                            dragThreshold: 4
                            grabPermissions: PointerHandler.CanTakeOverFromAnything

                            onActiveChanged: {
                                if (active) {
                                    childRow.dragCanceled = false;
                                    childRow.activeDragKey = childRow.dragKey;
                                    childRow.activeDragToken = root.dragSession.begin(childRow, childGrip, centroid.position.x, centroid.position.y, childRow.dragPayload, childRow.stream.childLabel, "1 stream", childRow.stream.iconPath, root.accent, childRow.activeDragKey);
                                    if (childRow.activeDragToken === 0) {
                                        childRow.dragCanceled = true;
                                        childRow.activeDragKey = "";
                                    }
                                } else {
                                    var completedToken = childRow.activeDragToken;
                                    Qt.callLater(function () {
                                        if (childDrag.active || completedToken === 0 || childRow.activeDragToken !== completedToken)
                                            return;
                                        if (root.dragSession)
                                            root.dragSession.finish(completedToken, childRow.dragCanceled);
                                        childRow.activeDragToken = 0;
                                        childRow.activeDragKey = "";
                                        childRow.dragCanceled = false;
                                    });
                                }
                            }

                            onActiveTranslationChanged: {
                                if (childRow.activeDragToken > 0 && root.dragSession)
                                    root.dragSession.updatePointer(childRow.activeDragToken, childGrip, centroid.position.x, centroid.position.y);
                            }

                            onCanceled: childRow.dragCanceled = true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: childRow.stream.childLabel
                            color: Shell.Theme.primaryText
                            elide: Text.ElideRight
                            font.family: Shell.Theme.sansFont
                            font.pixelSize: Shell.Theme.captionFontSize
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: childRow.statusText.length > 0
                            text: childRow.statusText
                            color: childRow.statusColor
                            elide: Text.ElideRight
                            font.family: Shell.Theme.sansFont
                            font.pixelSize: Shell.Theme.captionFontSize
                        }
                    }
                }
            }
        }
    }

    onStreamsChanged: syncStreamKeys()
    Component.onCompleted: syncStreamKeys()
}
