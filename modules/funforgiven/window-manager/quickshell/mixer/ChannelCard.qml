pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import ".." as Shell
import "../components" as Components
import "../components/StableKeys.js" as StableKeys
import "../services" as Services
import "DragModel.js" as DragModel

Rectangle {
    id: root

    required property var channel
    required property color accent
    required property var dropdownHost
    property var dragSession: null
    property var groupKeys: []
    property bool dropActive: false
    property bool dropHovering: false
    readonly property var outputs: Services.AudioService.outputsForChannel(channel.id)
    readonly property bool dragInProgress: dragSession !== null && dragSession.active
    readonly property string channelSymbol: {
        if (channel.id === "system")
            return "volume_up";
        if (channel.id === "game")
            return "sports_esports";
        if (channel.id === "voice")
            return "headset_mic";
        return "music_note";
    }

    function groupForKey(key) {
        return StableKeys.find(root.channel.groups, key, function (group) {
            return group.key;
        });
    }

    function missingGroup(key) {
        return {
            key: String(key),
            canonicalId: "",
            displayName: "",
            iconPath: "",
            streams: [],
            streamRefs: [],
            count: 0
        };
    }

    function syncGroupKeys() {
        var next = StableKeys.reconcile(root.groupKeys, root.channel.groups, function (group) {
            return group.key;
        });
        if (next !== root.groupKeys)
            root.groupKeys = next;
    }
    readonly property var bridgeAudio: channel && channel.bridge ? channel.bridge.audio : null
    readonly property bool channelMuted: bridgeAudio !== null && bridgeAudio.muted === true

    function dropPayload(drop) {
        if (!drop || !drop.source || !drop.source.dragPayload)
            return null;
        return DragModel.normalizePayload(drop.source.dragPayload);
    }

    function canAccept(payload) {
        return DragModel.canDrop(payload, root.channel.id, root.channel.sink !== null);
    }

    function clearDropState() {
        dropHovering = false;
        dropActive = false;
    }

    implicitWidth: 320
    implicitHeight: 660
    radius: Shell.Theme.radiusLarge
    color: Shell.Theme.baseSurface
    border.width: dropActive ? 2 : Shell.Theme.outlineWidth
    border.color: dropActive ? accent : (channel.status.state === "error" ? Shell.Theme.error : Shell.Theme.outline)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Shell.Theme.spacingLarge
        spacing: Shell.Theme.spacingMedium

        RowLayout {
            Layout.fillWidth: true
            spacing: Shell.Theme.spacingSmall

            Rectangle {
                Layout.preferredWidth: 46
                Layout.preferredHeight: 46
                radius: Shell.Theme.radiusMedium
                color: Shell.Theme.systemAccent

                Text {
                    anchors.centerIn: parent
                    text: root.channelSymbol
                    color: Shell.Theme.accentText
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 28
                    font.weight: Font.Medium
                    Accessible.ignored: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: root.channel.label
                    color: Shell.Theme.primaryText
                    elide: Text.ElideRight
                    font.family: Shell.Theme.sansFont
                    font.pixelSize: Shell.Theme.titleFontSize
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.channel.status.state !== "connected"
                    text: root.channel.status.message
                    color: root.channel.status.state === "error" ? Shell.Theme.errorText : Shell.Theme.secondaryText
                    elide: Text.ElideRight
                    font.family: Shell.Theme.sansFont
                    font.pixelSize: Shell.Theme.captionFontSize
                }
            }

            Components.StatusChip {
                visible: root.channel.isDefault || root.channel.isObservedDefault
                text: root.channel.isDefault && root.channel.isObservedDefault ? "Default" : (root.channel.isObservedDefault ? "Live default" : "Expected")
                accent: root.accent
                tone: root.channel.isDefault && !root.channel.isObservedDefault ? "warning" : "accent"
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: gainControls.implicitHeight + Shell.Theme.spacingMedium * 2
            radius: Shell.Theme.radiusMedium
            color: Shell.Theme.elevatedSurface

            RowLayout {
                id: gainControls

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Shell.Theme.spacingMedium
                spacing: Shell.Theme.spacingMedium

                ChannelGain {
                    Layout.fillWidth: true
                    channel: root.channel
                    accent: root.accent
                }

                Components.IconButton {
                    Layout.preferredWidth: Shell.Theme.controlLargeSize
                    Layout.preferredHeight: Shell.Theme.controlLargeSize
                    Layout.alignment: Qt.AlignBottom
                    iconSource: Quickshell.iconPath(root.channelMuted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic", "audio-volume-high")
                    iconSize: Shell.Theme.iconMediumSize
                    accessibleName: (root.channelMuted ? "Unmute " : "Mute ") + root.channel.label
                    tooltipText: root.channelMuted ? "Unmute" : "Mute"
                    accent: root.accent
                    checked: root.channelMuted
                    enabled: root.bridgeAudio !== null
                    onClicked: button => {
                        if (button === Qt.LeftButton)
                            Services.AudioActions.setChannelMuted(root.channel.id, !root.channelMuted);
                    }
                }
            }
        }

        OutputPicker {
            Layout.fillWidth: true
            channel: root.channel
            outputs: root.outputs
            accent: root.accent
            dropdownHost: root.dropdownHost
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Shell.Theme.spacingXSmall

            Text {
                text: "Applications"
                color: Shell.Theme.secondaryText
                font.family: Shell.Theme.sansFont
                font.pixelSize: Shell.Theme.labelFontSize
                font.weight: Font.DemiBold
            }

            Item {
                Layout.fillWidth: true
            }

            Components.StatusChip {
                text: String(root.channel.groups.length)
                accent: root.accent
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: streamView

                anchors.fill: parent
                anchors.rightMargin: streamScroll.visible ? Shell.Theme.spacingSmall : 0
                clip: true
                interactive: !root.dragInProgress
                contentWidth: width
                contentHeight: streamColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: streamColumn

                    width: parent.width
                    spacing: Shell.Theme.spacingSmall

                    Repeater {
                        model: root.groupKeys

                        delegate: StreamCard {
                            required property string modelData
                            readonly property var liveGroup: root.groupForKey(modelData)

                            Layout.fillWidth: true
                            visible: liveGroup !== null
                            group: liveGroup || root.missingGroup(modelData)
                            accent: root.accent
                            sourceChannelId: root.channel.id
                            dragSession: root.dragSession
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 64
                        visible: root.channel.groups.length === 0
                        radius: Shell.Theme.radiusMedium
                        color: Shell.Theme.baseSurface

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - Shell.Theme.spacingLarge * 2
                            text: "No active audio"
                            color: Shell.Theme.secondaryText
                            horizontalAlignment: Text.AlignHCenter
                            font.family: Shell.Theme.sansFont
                            font.pixelSize: Shell.Theme.bodyFontSize
                        }
                    }
                }
            }

            Rectangle {
                id: streamScroll

                visible: streamView.contentHeight > streamView.height + 1
                anchors.right: parent.right
                width: 4
                height: visible ? Math.max(28, parent.height * parent.height / streamView.contentHeight) : 0
                y: visible ? (parent.height - height) * streamView.visibleArea.yPosition / Math.max(0.001, 1 - streamView.visibleArea.heightRatio) : 0
                radius: Shell.Theme.radiusPill
                color: Shell.Theme.outlineStrong
            }
        }
    }

    Rectangle {
        visible: root.dropHovering && root.dragInProgress
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Shell.Theme.spacingMedium
        height: 34
        z: 50
        radius: Shell.Theme.radiusPill
        color: root.dropActive ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, Shell.Theme.selectedOverlayOpacity) : Shell.Theme.errorSurface

        Text {
            anchors.centerIn: parent
            text: root.dropActive ? "Move here" : "Unavailable"
            color: root.dropActive ? Shell.Theme.primaryText : Shell.Theme.errorText
            font.family: Shell.Theme.sansFont
            font.pixelSize: Shell.Theme.captionFontSize
            font.weight: Font.DemiBold
        }
    }

    DropArea {
        anchors.fill: parent
        z: 60
        keys: ["funforgiven.audio.stream"]

        onEntered: function (drag) {
            root.dropHovering = true;
            root.dropActive = root.canAccept(root.dropPayload(drag));
        }

        onExited: {
            root.clearDropState();
        }

        onDropped: function (drop) {
            root.clearDropState();
            var payload = root.dropPayload(drop);
            if (!root.canAccept(payload))
                return;
            if (Services.AudioActions.movePayload(payload, root.channel.id))
                drop.acceptProposedAction();
        }
    }

    Connections {
        target: root.dragSession

        function onActiveChanged() {
            if (!root.dragSession || !root.dragSession.active)
                root.clearDropState();
        }
    }

    onChannelChanged: syncGroupKeys()
    Component.onCompleted: syncGroupKeys()

    Behavior on border.color {
        ColorAnimation {
            duration: Shell.Theme.animationFast
            easing.type: Shell.Theme.easingStandard
        }
    }
}
