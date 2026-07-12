pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".." as Shell
import "../components" as Components
import "../components/StableKeys.js" as StableKeys
import "../services" as Services
import "DockModel.js" as DockModel

Scope {
    id: root

    readonly property var selectedScreen: selectScreen(Quickshell.screens, Shell.ShellConfig.dockOutput)
    readonly property int appRevision: Services.AppService.revision
    readonly property var dockItems: buildDockItems(Services.NiriService.windows, Shell.ShellConfig.pinnedDesktopIds, appRevision)
    property var dockKeys: []
    readonly property int pinnedCount: dockItems.filter(item => item.pinned).length
    readonly property bool hasUnpinned: dockItems.some(item => !item.pinned)
    readonly property int appExtent: 56
    readonly property int groupSeparatorExtent: pinnedCount > 0 && hasUnpinned ? Shell.Theme.spacingMedium + Shell.Theme.outlineWidth : 0
    readonly property int listWidth: dockItems.length * appExtent + Math.max(0, dockItems.length - 1) * Shell.Theme.spacingSmall + groupSeparatorExtent
    readonly property int estimatedWidth: Shell.Theme.spacingSmall * 2 + appExtent + Shell.Theme.spacingSmall * 2 + Shell.Theme.outlineWidth + listWidth

    function selectScreen(screens, outputName) {
        for (let index = 0; index < screens.length; index += 1) {
            if (screens[index].name === outputName)
                return screens[index];
        }
        return null;
    }

    function pinGroup(desktopId) {
        const identity = Services.AppService.resolveDesktopId(desktopId);
        return {
            key: desktopId,
            canonicalId: identity.canonicalId || desktopId,
            desktopId: identity.desktopId || desktopId,
            displayName: identity.displayName || desktopId,
            iconPath: identity.iconPath,
            pinned: true,
            windows: [],
            focused: false,
            urgent: false
        };
    }

    function focusTimestamp(window) {
        const stamp = window.focus_timestamp;
        if (!stamp || typeof stamp !== "object")
            return [0, 0];
        return [Number(stamp.secs) || 0, Number(stamp.nanos) || 0];
    }

    function recentWindowOrder(left, right) {
        const leftStamp = focusTimestamp(left);
        const rightStamp = focusTimestamp(right);
        if (leftStamp[0] !== rightStamp[0])
            return rightStamp[0] - leftStamp[0];
        if (leftStamp[1] !== rightStamp[1])
            return rightStamp[1] - leftStamp[1];
        const leftId = String(left.id);
        const rightId = String(right.id);
        return leftId < rightId ? -1 : (leftId > rightId ? 1 : 0);
    }

    function dockItemForKey(key) {
        return StableKeys.find(root.dockItems, key, function (group) {
            return group.key;
        });
    }

    function missingDockItem(key) {
        return {
            key: String(key),
            canonicalId: String(key),
            desktopId: "",
            displayName: String(key),
            iconPath: "",
            pinned: false,
            windows: [],
            focused: false,
            urgent: false
        };
    }

    function syncDockKeys() {
        const next = StableKeys.reconcile(root.dockKeys, root.dockItems, function (group) {
            return group.key;
        });
        if (next !== root.dockKeys)
            root.dockKeys = next;
    }

    function buildDockItems(windows, pinnedDesktopIds, revision) {
        void revision;

        const pins = Array.from(pinnedDesktopIds || []);
        const groups = Object.create(null);
        const pinned = [];

        for (let pinIndex = 0; pinIndex < pins.length; pinIndex += 1) {
            const desktopId = String(pins[pinIndex]);
            if (groups[desktopId])
                continue;
            const group = pinGroup(desktopId);
            groups[desktopId] = group;
            pinned.push(group);
        }

        for (let windowIndex = 0; windowIndex < windows.length; windowIndex += 1) {
            const window = windows[windowIndex];
            const identity = Services.AppService.resolveWindow(window);
            const key = identity.canonicalId || `window-${window.id}`;
            let group = groups[key];

            if (!group) {
                group = {
                    key: key,
                    canonicalId: key,
                    desktopId: identity.desktopId || "",
                    displayName: identity.displayName || window.app_id || window.title || "Unknown application",
                    iconPath: identity.iconPath || Quickshell.iconPath("application-x-executable"),
                    pinned: false,
                    windows: [],
                    focused: false,
                    urgent: false
                };
                groups[key] = group;
            } else if (group.iconPath.length === 0 && identity.iconPath) {
                group.iconPath = identity.iconPath;
            }

            group.windows.push(window);
            group.focused = group.focused || window.is_focused === true;
            group.urgent = group.urgent || window.is_urgent === true;
        }

        const unpinned = [];
        const keys = Object.keys(groups);
        for (let keyIndex = 0; keyIndex < keys.length; keyIndex += 1) {
            const group = groups[keys[keyIndex]];
            group.windows.sort(recentWindowOrder);
            if (!group.pinned && group.windows.length > 0)
                unpinned.push(group);
        }
        return pinned.concat(DockModel.orderUnpinned(unpinned));
    }

    function activateGroup(group) {
        const desktopId = group.desktopId || group.canonicalId;
        if (Services.AppService.isLaunchPending(desktopId))
            return;

        if (group.windows.length === 0) {
            Services.AppService.launchDesktopId(desktopId);
            return;
        }

        if (group.windows.length === 1) {
            Services.NiriService.focusWindow(group.windows[0].id);
            return;
        }

        let focusedWindow = null;
        for (let index = 0; index < group.windows.length; index += 1) {
            if (group.windows[index].is_focused === true) {
                focusedWindow = group.windows[index];
                break;
            }
        }
        if (focusedWindow === null) {
            Services.NiriService.focusWindow(group.windows[0].id);
            return;
        }

        const stableWindows = group.windows.slice().sort(function (left, right) {
            return String(left.id).localeCompare(String(right.id));
        });
        let focusedIndex = 0;
        for (let stableIndex = 0; stableIndex < stableWindows.length; stableIndex += 1) {
            if (String(stableWindows[stableIndex].id) === String(focusedWindow.id)) {
                focusedIndex = stableIndex;
                break;
            }
        }
        Services.NiriService.focusWindow(stableWindows[(focusedIndex + 1) % stableWindows.length].id);
    }

    PanelWindow { // qmllint disable uncreatable-type
        id: dockWindow

        screen: root.selectedScreen
        visible: root.selectedScreen !== null && Shell.ShellConfig.dockMode === "always-visible"
        implicitWidth: root.selectedScreen ? Math.min(root.estimatedWidth, root.selectedScreen.width - Shell.Theme.spacingLarge * 2) : root.estimatedWidth
        implicitHeight: 72
        color: "transparent"
        anchors.bottom: true
        margins.bottom: Shell.Theme.spacingLarge // qmllint disable unqualified unresolved-type
        exclusiveZone: implicitHeight + Shell.Theme.spacingLarge
        focusable: false
        aboveWindows: true
        WlrLayershell.namespace: "funforgiven:dock"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Components.Surface {
            anchors.fill: parent
            elevated: true
            radius: Shell.Theme.radiusLarge
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Shell.Theme.spacingSmall
            spacing: Shell.Theme.spacingSmall

            DockLauncher {
                Layout.preferredWidth: root.appExtent
                Layout.fillHeight: true
            }

            Rectangle {
                Layout.preferredWidth: Shell.Theme.outlineWidth
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter
                radius: Shell.Theme.radiusPill
                color: Shell.Theme.outline
            }

            ListView {
                id: dockList

                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: ListView.Horizontal
                spacing: Shell.Theme.spacingSmall
                model: root.dockKeys
                clip: false
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentWidth > width

                delegate: Item {
                    id: dockDelegate

                    required property string modelData
                    required property int index

                    readonly property var liveGroup: root.dockItemForKey(modelData)
                    readonly property var appGroup: liveGroup || root.missingDockItem(modelData)
                    readonly property bool separatorBefore: !appGroup.pinned && index === root.pinnedCount && root.pinnedCount > 0

                    width: root.appExtent + (separatorBefore ? root.groupSeparatorExtent : 0)
                    height: dockList.height

                    Rectangle {
                        visible: dockDelegate.separatorBefore
                        anchors.left: parent.left
                        anchors.leftMargin: Shell.Theme.spacingSmall / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: Shell.Theme.outlineWidth
                        height: 28
                        radius: Shell.Theme.radiusPill
                        color: Shell.Theme.outline
                    }

                    DockApp {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.appExtent
                        height: parent.height
                        visible: dockDelegate.liveGroup !== null
                        appGroup: dockDelegate.appGroup
                        pending: Services.AppService.isLaunchPending(dockDelegate.appGroup.desktopId)
                        errorText: Services.AppService.lastLaunchFailureDesktopId === dockDelegate.appGroup.desktopId ? Services.AppService.lastLaunchFailureMessage : ""
                        onActivated: root.activateGroup(dockDelegate.appGroup)
                    }
                }
            }
        }
    }

    onDockItemsChanged: syncDockKeys()
    Component.onCompleted: syncDockKeys()
}
