// Centered modal behavior adapted from the MIT-licensed snapshot
// d82d86df5cb932fc275dcf30c35cd72705a21065; see THIRD_PARTY_NOTICES.md.
// Pointer-selection behavior adapted from the MIT-licensed legacy-v4 snapshot
// a48885b9fec485c903c955749a7da6e30147cd38; history/settings were not retained.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".." as Shell
import "../components" as Components
import "../services" as Services
import "LauncherModel.js" as LauncherModel

Scope {
    id: root

    property bool opened: false
    property bool openRequested: false
    property alias query: launcherSearch.text
    property int selectedIndex: -1
    property string requestedDesktopId: ""
    property var pointerAnchor: null
    property bool pointerGuardReady: false

    readonly property int appRevision: Services.AppService.revision
    readonly property var applications: Services.AppService.launcherApplications(appRevision)
    readonly property var results: LauncherModel.filterApplications(applications, query)
    readonly property var selectedScreen: configuredScreen()
    readonly property var pendingDesktopIds: Services.AppService.pendingDesktopIds
    readonly property string pendingDesktopId: pendingDesktopIds.length > 0 ? pendingDesktopIds[0] : ""
    readonly property string failureDesktopId: Services.AppService.lastLaunchFailureDesktopId
    readonly property string failureMessage: Services.AppService.lastLaunchFailureMessage

    function configuredScreen() {
        for (var index = 0; index < Quickshell.screens.length; index += 1) {
            var screen = Quickshell.screens[index];
            if (screen.name === Shell.ShellConfig.dockOutput) {
                return screen;
            }
        }
        return null;
    }

    function focusSearchWhenMapped(): void {
        if (!root.opened || !launcherWindow.backingWindowVisible) {
            return;
        }
        Qt.callLater(function () {
            if (root.opened && launcherWindow.backingWindowVisible) {
                launcherSearch.focusInput();
            }
        });
    }

    function showAfterOutputFocus(): void {
        if (!root.openRequested) {
            return;
        }
        root.openRequested = false;
        root.opened = true;
        pointerGuardTimer.restart();
        root.focusSearchWhenMapped();
    }

    function open(): void {
        if (root.opened) {
            root.focusSearchWhenMapped();
            return;
        }
        if (root.openRequested) {
            return;
        }

        root.query = "";
        root.requestedDesktopId = "";
        root.selectedIndex = root.results.length > 0 ? 0 : -1;
        root.pointerAnchor = null;
        root.pointerGuardReady = false;
        root.openRequested = true;

        if (!Services.NiriService.focusMonitor(Shell.ShellConfig.dockOutput)) {
            root.showAfterOutputFocus();
        }
    }

    function close(): void {
        root.openRequested = false;
        root.opened = false;
        root.pointerGuardReady = false;
        pointerGuardTimer.stop();
    }

    function toggle(): void {
        if (root.opened || root.openRequested) {
            root.close();
        } else {
            root.open();
        }
    }

    function isPending(desktopId) {
        var revision = Services.AppService.launchStateRevision;
        void revision;
        return Services.AppService.isLaunchPending(desktopId);
    }

    function applicationName(desktopId) {
        for (var index = 0; index < root.applications.length; index += 1) {
            if (root.applications[index].id === desktopId) {
                return root.applications[index].name;
            }
        }
        return desktopId || "application";
    }

    function resetSelection() {
        root.selectedIndex = root.results.length > 0 ? 0 : -1;
        if (root.selectedIndex >= 0) {
            Qt.callLater(function () {
                resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            });
        }
    }

    function moveSelection(delta) {
        root.selectedIndex = LauncherModel.moveSelection(root.selectedIndex, delta, root.results.length);
        if (root.selectedIndex >= 0) {
            resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        }
    }

    function selectBoundary(last) {
        root.selectedIndex = root.results.length === 0 ? -1 : (last ? root.results.length - 1 : 0);
        if (root.selectedIndex >= 0) {
            resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        }
    }

    function launchApplication(application) {
        if (!application || root.isPending(application.id)) {
            return;
        }

        Services.AppService.clearLaunchFailure();
        root.requestedDesktopId = application.id;
        if (!Services.AppService.launchDesktopId(application.id)) {
            root.requestedDesktopId = "";
        }
    }

    function launchSelected() {
        if (root.selectedIndex < 0 || root.selectedIndex >= root.results.length) {
            return;
        }
        root.launchApplication(root.results[root.selectedIndex]);
    }

    function considerPointer(index, x, y) {
        var current = {
            x: x,
            y: y
        };
        if (root.pointerAnchor === null || !root.pointerGuardReady) {
            root.pointerAnchor = current;
            return;
        }
        if (!LauncherModel.pointerMovedEnough(root.pointerAnchor, current, 5)) {
            return;
        }
        root.pointerAnchor = current;
        if (index >= 0 && index < root.results.length) {
            root.selectedIndex = index;
        }
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            root.close();
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            root.moveSelection(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            root.moveSelection(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageDown) {
            root.moveSelection(7);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            root.moveSelection(-7);
            event.accepted = true;
        } else if (event.key === Qt.Key_Home) {
            root.selectBoundary(false);
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.selectBoundary(true);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.launchSelected();
            event.accepted = true;
        }
    }

    onResultsChanged: resetSelection()

    IpcHandler {
        target: "launcher"

        function open(): void {
            root.open();
        }

        function close(): void {
            root.close();
        }

        function toggle(): void {
            root.toggle();
        }

        function isVisible(): bool {
            return root.opened;
        }
    }

    Connections {
        target: Services.AppService

        function onLaunchSucceeded(desktopId) {
            if (desktopId !== root.requestedDesktopId) {
                return;
            }
            root.requestedDesktopId = "";
            root.close();
        }

        function onLaunchFailed(desktopId) {
            if (desktopId !== root.requestedDesktopId) {
                return;
            }
            root.requestedDesktopId = "";
            if (root.opened) {
                Qt.callLater(function () {
                    launcherSearch.focusInput();
                });
            }
        }
    }

    Connections {
        target: Services.NiriService

        function onActionSucceeded(actionName) {
            if (actionName === "focus-monitor") {
                root.showAfterOutputFocus();
            }
        }

        function onActionFailed(actionName, message) {
            void message;
            if (actionName === "focus-monitor") {
                root.showAfterOutputFocus();
            }
        }
    }

    Timer {
        id: pointerGuardTimer

        interval: 180
        onTriggered: root.pointerGuardReady = true
    }

    PanelWindow { // qmllint disable uncreatable-type
        id: launcherWindow

        screen: root.selectedScreen
        visible: root.opened && root.selectedScreen !== null
        onBackingWindowVisibleChanged: root.focusSearchWhenMapped()
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

        WlrLayershell.namespace: "funforgiven:launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Shell.Theme.baseSurface.r, Shell.Theme.baseSurface.g, Shell.Theme.baseSurface.b, 0.78)

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }

        Components.Surface {
            id: launcherCard

            anchors.centerIn: parent
            width: Math.min(680, launcherWindow.width - Shell.Theme.spacingLarge * 2)
            height: Math.min(640, launcherWindow.height - Shell.Theme.spacingLarge * 2)
            elevated: true
            accent: Shell.Theme.systemAccent
            outlineColor: Shell.Theme.outlineStrong
            radius: Shell.Theme.radiusLarge
            scale: root.opened ? 1 : 0.98
            opacity: root.opened ? 1 : 0

            Behavior on scale {
                NumberAnimation {
                    duration: Shell.Theme.animationFast
                    easing.type: Shell.Theme.easingStandard
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Shell.Theme.animationFast
                    easing.type: Shell.Theme.easingStandard
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: mouse => mouse.accepted = true
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Shell.Theme.spacingXLarge
                spacing: Shell.Theme.spacingMedium

                LauncherSearchField {
                    id: launcherSearch

                    Layout.fillWidth: true
                    onEdited: Services.AppService.clearLaunchFailure()
                    onNavigationKey: event => root.handleKey(event)
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: root.failureMessage.length > 0
                    implicitHeight: visible ? failureRow.implicitHeight + Shell.Theme.spacingMedium * 2 : 0
                    radius: Shell.Theme.radiusMedium
                    color: Shell.Theme.errorSurface
                    border.width: Shell.Theme.outlineWidth
                    border.color: Shell.Theme.error

                    Accessible.role: Accessible.AlertMessage
                    Accessible.name: failureText.text

                    RowLayout {
                        id: failureRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Shell.Theme.spacingMedium
                        anchors.rightMargin: Shell.Theme.spacingMedium
                        spacing: Shell.Theme.spacingMedium

                        Rectangle {
                            Layout.preferredWidth: 6
                            Layout.preferredHeight: 32
                            radius: Shell.Theme.radiusPill
                            color: Shell.Theme.error
                        }

                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: Shell.Theme.radiusPill
                            color: Shell.Theme.error

                            Text {
                                anchors.centerIn: parent
                                text: "!"
                                color: Shell.Theme.accentText
                                font.family: Shell.Theme.sansFont
                                font.pixelSize: Shell.Theme.labelFontSize
                                font.weight: Font.Bold
                                Accessible.ignored: true
                            }
                        }

                        Text {
                            id: failureText

                            Layout.fillWidth: true
                            text: "Could not start " + root.applicationName(root.failureDesktopId) + ": " + root.failureMessage
                            color: Shell.Theme.errorText
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            font.family: Shell.Theme.sansFont
                            font.pixelSize: Shell.Theme.bodyFontSize
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: root.pendingDesktopIds.length > 0
                    implicitHeight: visible ? pendingRow.implicitHeight + Shell.Theme.spacingSmall * 2 : 0
                    radius: Shell.Theme.radiusMedium
                    color: Shell.Theme.selectedSurface
                    border.width: Shell.Theme.outlineWidth
                    border.color: Shell.Theme.systemAccent

                    Accessible.role: Accessible.StaticText
                    Accessible.name: pendingText.text

                    RowLayout {
                        id: pendingRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Shell.Theme.spacingMedium
                        anchors.rightMargin: Shell.Theme.spacingMedium
                        spacing: Shell.Theme.spacingSmall

                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 8
                            radius: Shell.Theme.radiusPill
                            color: Shell.Theme.systemAccent
                        }

                        Text {
                            id: pendingText

                            Layout.fillWidth: true
                            text: "Starting " + root.applicationName(root.pendingDesktopId) + "…"
                            color: Shell.Theme.primaryText
                            elide: Text.ElideRight
                            font.family: Shell.Theme.sansFont
                            font.pixelSize: Shell.Theme.bodyFontSize
                            font.weight: Font.DemiBold
                        }

                        Components.StatusChip {
                            text: "Launching"
                            tone: "warning"
                            Accessible.ignored: true
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Shell.Theme.radiusLarge
                    color: Shell.Theme.baseSurface
                    border.width: Shell.Theme.outlineWidth
                    border.color: Shell.Theme.outline
                    clip: true

                    ListView {
                        id: resultList

                        anchors.fill: parent
                        anchors.margins: Shell.Theme.spacingSmall
                        model: root.results
                        currentIndex: root.selectedIndex
                        spacing: Shell.Theme.spacingXSmall
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: true
                        keyNavigationEnabled: false

                        delegate: LauncherResult {
                            required property var modelData
                            required property int index

                            width: ListView.view ? ListView.view.width : 0
                            application: modelData
                            resultIndex: index
                            selected: index === root.selectedIndex
                            pending: root.isPending(modelData.id)
                            failed: root.failureDesktopId === modelData.id
                            onActivated: root.launchApplication(modelData)
                            onPointerMoved: (resultIndex, sceneX, sceneY) => root.considerPointer(resultIndex, sceneX, sceneY)
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: root.results.length === 0
                        width: Math.min(parent.width - Shell.Theme.spacingLarge * 2, 420)
                        spacing: Shell.Theme.spacingMedium

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 64
                            height: 64
                            radius: Shell.Theme.radiusLarge
                            color: Shell.Theme.raisedSurface
                            border.width: Shell.Theme.outlineWidth
                            border.color: Shell.Theme.outlineStrong

                            Components.AppIcon {
                                anchors.centerIn: parent
                                width: 30
                                height: 30
                                iconSize: 30
                                source: Quickshell.iconPath("edit-find-symbolic", "system-search")
                                accessibleName: "No applications found"
                                Accessible.ignored: true
                            }
                        }

                        Text {
                            width: parent.width
                            text: root.query.length === 0 ? "No apps available" : "No matches"
                            color: Shell.Theme.primaryText
                            horizontalAlignment: Text.AlignHCenter
                            font.family: Shell.Theme.sansFont
                            font.pixelSize: Shell.Theme.titleFontSize
                            font.weight: Font.DemiBold
                        }

                        Text {
                            width: parent.width
                            text: root.query.length === 0 ? "No launchable apps found." : "Try another search."
                            color: Shell.Theme.secondaryText
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            font.family: Shell.Theme.sansFont
                            font.pixelSize: Shell.Theme.bodyFontSize
                        }
                    }
                }
            }
        }
    }
}
