pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".." as Shell
import "../components" as Components
import "../components/StableKeys.js" as StableKeys
import "../services" as Services

Scope {
    id: root

    property Item anchorItem: null
    property var selectedScreen: null
    property int topInset: 56
    property bool opened: false
    property var activeOutputPicker: null
    property var unroutedGroupKeys: []
    readonly property bool visible: mixerWindow.visible
    readonly property int targetWidth: 1480
    readonly property int targetHeight: 800
    readonly property int audioRevision: Services.AudioService.revision

    function channelForDefinition(definition, revision) {
        void revision;
        var live = Services.AudioService.channel(definition.id);
        if (live !== null)
            return live;
        return {
            id: definition.id,
            label: definition.label,
            sinkName: definition.sinkName,
            bridgeName: definition.bridgeName,
            isDefault: definition.isDefault === true,
            isObservedDefault: false,
            sink: null,
            sinkId: null,
            sinkSerial: null,
            bridge: null,
            bridgeId: null,
            bridgeSerial: null,
            volume: null,
            muted: false,
            output: null,
            status: {
                state: Services.AudioService.ready ? "error" : "connecting",
                message: Services.AudioService.ready ? "Logical channel is missing" : "Binding channel graph…"
            },
            groups: []
        };
    }

    function unroutedGroupForKey(key) {
        return StableKeys.find(Services.AudioService.unroutedGroups, key, function (group) {
            return group.key;
        });
    }

    function streamStateKey(stream) {
        return String(stream.id) + ":" + String(stream.serial);
    }

    function groupIsMoving(group) {
        return group && Array.isArray(group.streams) && group.streams.length > 0 && group.streams.every(function (stream) {
            return Services.AudioActions.pendingStreams[root.streamStateKey(stream)] !== undefined;
        });
    }

    function presentedUnroutedGroups() {
        return Services.AudioService.unroutedGroups.filter(function (group) {
            return !root.groupIsMoving(group);
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

    function syncUnroutedGroupKeys() {
        var next = StableKeys.reconcile(root.unroutedGroupKeys, root.presentedUnroutedGroups(), function (group) {
            return group.key;
        });
        if (next !== root.unroutedGroupKeys)
            root.unroutedGroupKeys = next;
    }

    function accentFor(channelId) {
        if (channelId === "system")
            return Shell.Theme.systemAccent;
        if (channelId === "game")
            return Shell.Theme.gameAccent;
        if (channelId === "voice")
            return Shell.Theme.voiceAccent;
        return Shell.Theme.musicAccent;
    }

    function openAt(item, targetScreen, barInset) {
        if (item === null || item === undefined || targetScreen === null || targetScreen === undefined) {
            dismiss();
            return;
        }
        if (anchorItem !== item || selectedScreen !== targetScreen) {
            dismissActiveChildPopup(false);
            mixerDragSession.cancel();
        }
        anchorItem = item;
        selectedScreen = targetScreen;
        topInset = Math.max(0, Number(barInset) || 0);
        opened = true;
    }

    function toggleAt(item, targetScreen, barInset) {
        if (opened && anchorItem === item && selectedScreen === targetScreen)
            dismiss();
        else
            openAt(item, targetScreen, barInset);
    }

    function openOutputPicker(picker) {
        if (!opened || picker === null || picker === undefined || picker.actionState.pending !== null)
            return false;
        mixerDragSession.cancel();
        activeOutputPicker = picker;
        return true;
    }

    function closeOutputPicker(picker, restoreFocus) {
        if (activeOutputPicker === null || (picker !== null && picker !== undefined && activeOutputPicker !== picker))
            return false;

        var closingPicker = activeOutputPicker;
        activeOutputPicker = null;
        if (restoreFocus === true && closingPicker && typeof closingPicker.restoreSelectorFocus === "function")
            closingPicker.restoreSelectorFocus();
        return true;
    }

    function dismissActiveChildPopup(restoreFocus) {
        return closeOutputPicker(activeOutputPicker, restoreFocus === true);
    }

    function reconcileActiveOutputPicker(picker) {
        if (activeOutputPicker !== picker || !outputDropdownLoader.item || typeof outputDropdownLoader.item.reconcileHighlightedOutput !== "function") // qmllint disable missing-property
            return;
        outputDropdownLoader.item.reconcileHighlightedOutput(); // qmllint disable missing-property
    }

    function dropdownWidth() {
        if (!activeOutputPicker)
            return 0;
        return Math.min(activeOutputPicker.desiredPopupWidth, Math.max(1, mixerSurface.width - Shell.Theme.spacingLarge * 2));
    }

    function dropdownHeight() {
        if (!activeOutputPicker)
            return 0;
        return Math.min(activeOutputPicker.desiredPopupHeight, Math.max(1, mixerSurface.height - Shell.Theme.spacingLarge * 2));
    }

    function dropdownX(dropdownWidth) {
        if (!activeOutputPicker || !activeOutputPicker.selectorAnchor)
            return Shell.Theme.spacingLarge;
        var anchor = activeOutputPicker.selectorAnchor;
        var mapped = anchor.mapToItem(mixerSurface, 0, anchor.height);
        var centered = mapped.x + (anchor.width - dropdownWidth) / 2;
        return Math.max(Shell.Theme.spacingLarge, Math.min(mixerSurface.width - Shell.Theme.spacingLarge - dropdownWidth, centered));
    }

    function dropdownY(dropdownHeight) {
        if (!activeOutputPicker || !activeOutputPicker.selectorAnchor)
            return Shell.Theme.spacingLarge;
        var anchor = activeOutputPicker.selectorAnchor;
        var top = anchor.mapToItem(mixerSurface, 0, 0).y;
        var bottom = anchor.mapToItem(mixerSurface, 0, anchor.height).y;
        var below = bottom + Shell.Theme.spacingXSmall;
        var bottomLimit = mixerSurface.height - Shell.Theme.spacingLarge;
        if (below + dropdownHeight <= bottomLimit)
            return below;
        return Math.max(Shell.Theme.spacingLarge, top - Shell.Theme.spacingXSmall - dropdownHeight);
    }

    function dismiss() {
        dismissActiveChildPopup(false);
        mixerDragSession.cancel();
        opened = false;
    }

    onOpenedChanged: {
        if (!opened) {
            root.dismissActiveChildPopup(false);
            mixerDragSession.cancel();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.opened
        onActivated: {
            if (root.activeOutputPicker !== null)
                root.dismissActiveChildPopup(true);
            else if (mixerDragSession.active)
                mixerDragSession.cancel();
            else
                root.dismiss();
        }
    }

    PanelWindow { // qmllint disable uncreatable-type
        id: mixerWindow

        screen: root.selectedScreen
        visible: root.opened && root.selectedScreen !== null
        color: "transparent"
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        focusable: true
        aboveWindows: true

        anchors {
            top: true
            right: true
            bottom: true
            left: true
        }

        WlrLayershell.namespace: "funforgiven:mixer"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        mask: Region {
            item: belowBarInput
        }

        Item {
            id: belowBarInput

            x: 0
            y: Math.min(mixerWindow.height, root.topInset)
            width: mixerWindow.width
            height: Math.max(0, mixerWindow.height - y)

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: root.dismiss()
            }
        }

        Components.Surface {
            id: mixerSurface

            x: Math.max(Shell.Theme.spacingLarge, mixerWindow.width - width - Shell.Theme.spacingLarge)
            y: Math.min(mixerWindow.height - height, root.topInset + Shell.Theme.spacingXSmall)
            width: Math.min(root.targetWidth, Math.max(1, mixerWindow.width - Shell.Theme.spacingLarge * 2))
            height: Math.min(root.targetHeight, Math.max(1, mixerWindow.height - root.topInset - Shell.Theme.spacingLarge))
            z: 10
            elevated: true
            radius: Shell.Theme.radiusLarge
            outlineColor: Shell.Theme.outlineStrong
            outlineWidth: Shell.Theme.outlineWidth

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: root.dismissActiveChildPopup(false)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Shell.Theme.spacingLarge
                spacing: Shell.Theme.spacingMedium

                Rectangle {
                    id: recentErrorsPanel

                    Layout.fillWidth: true
                    visible: Services.AudioActions.recentErrors.length > 0
                    implicitHeight: visible ? recentErrorRow.implicitHeight + Shell.Theme.spacingMedium * 2 : 0
                    radius: Shell.Theme.radiusMedium
                    color: Shell.Theme.errorSurface

                    RowLayout {
                        id: recentErrorRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Shell.Theme.spacingMedium
                        spacing: Shell.Theme.spacingMedium

                        Text {
                            Layout.fillWidth: true
                            text: Services.AudioActions.recentErrors.length > 0 ? Services.AudioActions.recentErrors[0].context + ": " + Services.AudioActions.recentErrors[0].message : ""
                            color: Shell.Theme.errorText
                            elide: Text.ElideRight
                            font.family: Shell.Theme.sansFont
                            font.pixelSize: Shell.Theme.captionFontSize
                        }

                        Components.StatusChip {
                            visible: Services.AudioActions.recentErrors.length > 1
                            text: "+" + (Services.AudioActions.recentErrors.length - 1) + " more"
                            tone: "error"
                        }

                        Components.ActionButton {
                            text: "Clear"
                            compact: true
                            variant: "text"
                            onClicked: Services.AudioActions.clearRecentErrors()
                        }
                    }
                }

                Rectangle {
                    id: unroutedPanel

                    Layout.fillWidth: true
                    visible: root.unroutedGroupKeys.length > 0
                    implicitHeight: visible ? unroutedContent.implicitHeight + Shell.Theme.spacingMedium * 2 : 0
                    radius: Shell.Theme.radiusMedium
                    color: Shell.Theme.warningSurface

                    ColumnLayout {
                        id: unroutedContent

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Shell.Theme.spacingMedium
                        spacing: Shell.Theme.spacingSmall

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: "Unrouted applications"
                                color: Shell.Theme.warningText
                                font.family: Shell.Theme.sansFont
                                font.pixelSize: Shell.Theme.labelFontSize
                                font.weight: Font.DemiBold
                            }
                        }

                        Flickable {
                            Layout.fillWidth: true
                            implicitHeight: Math.min(164, unroutedRow.implicitHeight)
                            contentWidth: unroutedRow.implicitWidth
                            contentHeight: height
                            clip: true
                            interactive: !mixerDragSession.active
                            boundsBehavior: Flickable.StopAtBounds

                            RowLayout {
                                id: unroutedRow

                                height: parent.height
                                spacing: Shell.Theme.spacingSmall

                                Repeater {
                                    model: root.unroutedGroupKeys

                                    delegate: StreamCard {
                                        required property string modelData
                                        readonly property var liveGroup: root.unroutedGroupForKey(modelData)

                                        Layout.preferredWidth: 300
                                        visible: liveGroup !== null
                                        group: liveGroup || root.missingGroup(modelData)
                                        accent: Shell.Theme.warning
                                        sourceChannelId: ""
                                        dragSession: mixerDragSession
                                        unrouted: true
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Flickable {
                        id: channelViewport

                        anchors.fill: parent
                        anchors.bottomMargin: channelScroll.visible ? Shell.Theme.spacingSmall : 0
                        clip: true
                        interactive: !mixerDragSession.active && contentWidth > width
                        contentWidth: channelRow.implicitWidth
                        contentHeight: height
                        boundsBehavior: Flickable.StopAtBounds

                        RowLayout {
                            id: channelRow

                            height: parent.height
                            spacing: Shell.Theme.spacingMedium

                            Repeater {
                                model: Shell.ShellConfig.audioChannels

                                delegate: ChannelCard {
                                    required property var modelData

                                    Layout.preferredWidth: Math.max(300, (channelViewport.width - Shell.Theme.spacingMedium * 3) / 4)
                                    Layout.fillHeight: true
                                    channel: root.channelForDefinition(modelData, root.audioRevision)
                                    accent: root.accentFor(modelData.id)
                                    dropdownHost: root
                                    dragSession: mixerDragSession
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: channelScroll

                        visible: channelViewport.contentWidth > channelViewport.width + 1
                        anchors.bottom: parent.bottom
                        height: 4
                        width: visible ? Math.max(40, parent.width * parent.width / channelViewport.contentWidth) : 0
                        x: visible ? (parent.width - width) * channelViewport.visibleArea.xPosition / Math.max(0.001, 1 - channelViewport.visibleArea.widthRatio) : 0
                        radius: Shell.Theme.radiusPill
                        color: Shell.Theme.outlineStrong
                    }
                }
            }

            Loader {
                id: outputDropdownLoader

                active: root.activeOutputPicker !== null
                visible: active
                sourceComponent: root.activeOutputPicker ? root.activeOutputPicker.dropdownComponent : null
                width: root.dropdownWidth()
                height: root.dropdownHeight()
                x: {
                    void channelViewport.contentX;
                    void recentErrorsPanel.height;
                    void unroutedPanel.height;
                    return root.dropdownX(width);
                }
                y: {
                    void recentErrorsPanel.height;
                    void unroutedPanel.height;
                    return root.dropdownY(height);
                }
                z: 900
            }
        }

        DragSession {
            id: mixerDragSession
        }
    }

    Component.onCompleted: syncUnroutedGroupKeys()

    Connections {
        target: Services.AudioService

        function onUnroutedGroupsChanged() {
            root.syncUnroutedGroupKeys();
        }
    }

    Connections {
        target: Services.AudioActions

        function onPendingStreamsChanged() {
            root.syncUnroutedGroupKeys();
        }
    }
}
