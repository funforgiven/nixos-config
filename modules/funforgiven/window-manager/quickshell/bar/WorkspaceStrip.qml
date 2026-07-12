pragma ComponentBehavior: Bound

import QtQuick
import ".." as Shell
import "../components" as Components
import "../components/StableKeys.js" as StableKeys
import "../services" as Services

Item {
    id: root

    required property string outputName

    readonly property var workspaceModel: {
        void Services.NiriService.workspaces;
        return Services.NiriService.workspacesForOutput(outputName);
    }
    readonly property var allWindows: Services.NiriService.windows
    readonly property int appRevision: Services.AppService.revision
    property var workspaceKeys: []

    function workspaceForKey(key) {
        return StableKeys.find(root.workspaceModel, key, function (workspace) {
            return workspace.id;
        });
    }

    function windowForKey(key) {
        return StableKeys.find(root.allWindows, key, function (window) {
            return window.id;
        });
    }

    function missingWorkspace(key) {
        return {
            id: String(key),
            idx: "",
            name: "",
            is_active: false,
            is_focused: false,
            is_urgent: false
        };
    }

    function missingWindow(key) {
        return {
            id: String(key),
            title: "",
            app_id: "",
            is_focused: false,
            is_urgent: false
        };
    }

    function syncWorkspaceKeys() {
        const next = StableKeys.reconcile(root.workspaceKeys, root.workspaceModel, function (workspace) {
            return workspace.id;
        });
        if (next !== root.workspaceKeys)
            root.workspaceKeys = next;
    }

    implicitWidth: workspaceRow.implicitWidth
    implicitHeight: Shell.Theme.controlCompactSize
    opacity: Services.NiriService.stale ? 0.55 : 1
    clip: true

    Behavior on opacity {
        NumberAnimation {
            duration: Shell.Theme.animationFast
        }
    }

    Flickable {
        anchors.fill: parent
        contentWidth: workspaceRow.implicitWidth
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentWidth > width
        clip: true

        Row {
            id: workspaceRow

            height: parent.height
            spacing: Shell.Theme.spacingXSmall

            Repeater {
                model: root.workspaceKeys

                delegate: Item {
                    id: workspaceDelegate

                    required property string modelData

                    readonly property var liveWorkspace: root.workspaceForKey(modelData)
                    readonly property var workspace: liveWorkspace || root.missingWorkspace(modelData)
                    readonly property var liveWindows: {
                        void root.allWindows;
                        return Services.NiriService.windowsForWorkspace(workspace.id);
                    }
                    property var windowKeys: []
                    readonly property int windowCount: liveWindows.length
                    readonly property bool occupied: windowCount > 0
                    readonly property bool activeOnOutput: workspace.is_active === true
                    readonly property bool globallyFocused: workspace.is_focused === true
                    readonly property bool urgent: workspace.is_urgent === true
                    readonly property real emptyWidth: activeOnOutput ? 30 : 22
                    readonly property real occupiedWidth: windowCount * Shell.Theme.controlCompactSize + Shell.Theme.spacingXSmall * 2

                    function syncWindowKeys() {
                        const next = StableKeys.reconcile(workspaceDelegate.windowKeys, workspaceDelegate.liveWindows, function (window) {
                            return window.id;
                        });
                        if (next !== workspaceDelegate.windowKeys)
                            workspaceDelegate.windowKeys = next;
                    }

                    width: occupied ? occupiedWidth : emptyWidth
                    height: root.height
                    visible: liveWorkspace !== null
                    scale: workspacePointer.pressed && !workspaceIconsHover.hovered ? Shell.Theme.pressedScale : 1

                    Accessible.name: workspace.name ? `Workspace ${workspace.name}` : `Workspace ${workspace.idx}`
                    Accessible.description: occupied ? `${windowCount} window${windowCount === 1 ? "" : "s"}` : "Empty"
                    Accessible.role: Accessible.Button
                    Accessible.onPressAction: Services.NiriService.focusWorkspace(workspace.id)

                    Components.Surface {
                        anchors.fill: parent
                        interactive: true
                        hovered: workspacePointer.containsMouse
                        pressed: workspacePointer.pressed && !workspaceIconsHover.hovered
                        selected: workspaceDelegate.activeOnOutput
                        accent: workspaceDelegate.urgent ? Shell.Theme.error : Shell.Theme.systemAccent
                        surfaceColor: workspaceDelegate.occupied ? Shell.Theme.baseSurface : "transparent"
                        outlineColor: workspaceDelegate.urgent ? Shell.Theme.error : (workspaceDelegate.globallyFocused ? Shell.Theme.systemAccent : "transparent")
                        outlineWidth: workspaceDelegate.globallyFocused || workspaceDelegate.urgent ? Shell.Theme.outlineWidth : 0
                        radius: Shell.Theme.radiusPill
                    }

                    Behavior on scale {
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

                    MouseArea {
                        id: workspacePointer

                        anchors.fill: parent
                        enabled: !Services.NiriService.stale
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.NiriService.focusWorkspace(workspaceDelegate.workspace.id)
                    }

                    Rectangle {
                        visible: !workspaceDelegate.occupied
                        anchors.centerIn: parent
                        width: workspaceDelegate.activeOnOutput ? 12 : 6
                        height: width
                        radius: Shell.Theme.radiusPill
                        color: workspaceDelegate.urgent ? Shell.Theme.error : (workspaceDelegate.activeOnOutput ? Shell.Theme.systemAccent : Shell.Theme.tertiaryText)

                        Behavior on width {
                            NumberAnimation {
                                duration: Shell.Theme.animationFast
                                easing.type: Shell.Theme.easingStandard
                            }
                        }
                    }

                    Row {
                        id: workspaceIcons

                        anchors.centerIn: parent
                        visible: workspaceDelegate.occupied
                        height: parent.height
                        spacing: 0

                        HoverHandler {
                            id: workspaceIconsHover
                        }

                        Repeater {
                            model: workspaceDelegate.windowKeys

                            delegate: Item {
                                id: windowDelegate

                                required property string modelData

                                readonly property var liveWindow: root.windowForKey(modelData)
                                readonly property var windowModel: liveWindow || root.missingWindow(modelData)
                                readonly property bool focused: windowModel.is_focused === true
                                readonly property bool urgent: windowModel.is_urgent === true
                                readonly property bool containsMouse: windowPointer.containsMouse
                                readonly property string iconSource: {
                                    void root.appRevision;
                                    return Services.AppService.iconPathForWindow(windowModel);
                                }

                                width: Shell.Theme.controlCompactSize
                                height: workspaceIcons.height
                                visible: liveWindow !== null
                                scale: windowPointer.pressed ? Shell.Theme.pressedScale : 1

                                Accessible.name: windowModel.title || windowModel.app_id || "Window"
                                Accessible.description: `Window on workspace ${workspaceDelegate.workspace.idx}`
                                Accessible.role: Accessible.Button
                                Accessible.onPressAction: Services.NiriService.focusWindow(windowModel.id)

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    color: windowPointer.pressed ? Shell.Theme.pressedSurface : (windowPointer.containsMouse ? Shell.Theme.hoverSurface : "transparent")
                                    radius: Shell.Theme.radiusSmall
                                }

                                Components.AppIcon {
                                    anchors.centerIn: parent
                                    width: Shell.Theme.iconLargeSize
                                    height: Shell.Theme.iconLargeSize
                                    iconSize: Shell.Theme.iconLargeSize
                                    source: windowDelegate.iconSource
                                    accessibleName: windowDelegate.windowModel.title || windowDelegate.windowModel.app_id || "Window"
                                    opacity: workspaceDelegate.activeOnOutput || windowDelegate.focused ? 1 : 0.72
                                }

                                Rectangle {
                                    visible: windowDelegate.focused || windowDelegate.urgent
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 2
                                    width: windowDelegate.focused ? 16 : 6
                                    height: 3
                                    radius: Shell.Theme.radiusPill
                                    color: windowDelegate.urgent ? Shell.Theme.error : Shell.Theme.systemAccent
                                }

                                MouseArea {
                                    id: windowPointer

                                    anchors.fill: parent
                                    enabled: !Services.NiriService.stale
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        mouse.accepted = true;
                                        Services.NiriService.focusWindow(windowDelegate.windowModel.id);
                                    }
                                }

                                Components.Tooltip {
                                    visible: windowPointer.containsMouse
                                    text: windowDelegate.windowModel.title || windowDelegate.windowModel.app_id || "Untitled window"
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Shell.Theme.animationFast
                                        easing.type: Shell.Theme.easingStandard
                                    }
                                }
                            }
                        }
                    }

                    onLiveWindowsChanged: syncWindowKeys()
                    Component.onCompleted: syncWindowKeys()

                    Components.Tooltip {
                        visible: workspacePointer.containsMouse && !workspaceIconsHover.hovered
                        text: {
                            const state = workspaceDelegate.globallyFocused ? "focused" : (workspaceDelegate.activeOnOutput ? "active" : "inactive");
                            const occupancy = workspaceDelegate.occupied ? `${workspaceDelegate.windowCount} window${workspaceDelegate.windowCount === 1 ? "" : "s"}` : "empty";
                            return `${workspaceDelegate.workspace.name || `Workspace ${workspaceDelegate.workspace.idx}`} · ${state}, ${occupancy}`;
                        }
                    }
                }
            }
        }
    }

    onWorkspaceModelChanged: syncWorkspaceKeys()
    Component.onCompleted: syncWorkspaceKeys()
}
