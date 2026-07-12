// QsMenuOpener rendering and submenu drill-down are adapted from the
// MIT-licensed snapshots a48885b9fec485c903c955749a7da6e30147cd38 and
// d82d86df5cb932fc275dcf30c35cd72705a21065. See THIRD_PARTY_NOTICES.md.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import ".." as Shell
import "../components" as Components

PanelWindow { // qmllint disable uncreatable-type
    id: root

    property real barHeight: 0
    property Item anchorItem: null
    property var topLevelMenu: null
    property var currentMenu: null
    property var menuStack: []
    property string currentTitle: ""
    property int selectedIndex: -1
    property bool announcedOpen: false
    property int lifecycleSerial: 0
    property real menuX: Shell.Theme.spacingLarge
    property real menuY: Math.max(barHeight, Shell.Theme.spacingLarge)

    readonly property var entries: menuOpener.children ? menuOpener.children.values : []
    readonly property int outerPadding: Shell.Theme.spacingSmall
    readonly property int visualInset: Shell.Theme.spacingXSmall
    readonly property int rowPadding: Shell.Theme.spacingMedium
    readonly property int leadingSlotWidth: Shell.Theme.iconMediumSize
    readonly property int trailingSlotWidth: Shell.Theme.iconSmallSize
    readonly property int minimumPopupWidth: 160
    readonly property int maximumPopupWidth: screen ? Math.min(520, Math.max(1, screen.width - Shell.Theme.spacingXLarge * 2)) : 520
    readonly property real measuredContentWidth: Math.max(widestEntryContentWidth(), headerContentWidth())
    readonly property real desiredPopupWidth: Math.min(maximumPopupWidth, Math.max(Math.min(minimumPopupWidth, maximumPopupWidth), outerPadding * 2 + measuredContentWidth))
    readonly property int interactiveRowHeight: Shell.Theme.controlCompactSize + visualInset * 2
    readonly property int headerHeight: menuStack.length > 0 ? interactiveRowHeight : 0
    readonly property int maximumContentHeight: screen ? Math.max(160, screen.height - 96) : 560
    readonly property real desiredListHeight: entries.length === 0 ? Shell.Theme.controlSize : Math.min(Math.max(Shell.Theme.controlCompactSize, menuList.contentHeight), maximumContentHeight - headerHeight - Shell.Theme.spacingSmall * 2)
    readonly property real desiredPopupHeight: outerPadding * 2 + headerHeight + desiredListHeight
    readonly property bool hasLeadingContent: root.entries.some(function (entry) {
        return root.entryHasLeadingContent(entry);
    })

    signal menuDismissed

    function isSelectable(entry) {
        return entry !== null && entry !== undefined && entry.isSeparator !== true && entry.enabled !== false;
    }

    function entryAt(index) {
        if (index < 0 || index >= root.entries.length)
            return null;
        return root.entries[index];
    }

    function entryHasLeadingContent(entry) {
        return entry !== null && entry !== undefined && entry.isSeparator !== true && (entry.buttonType !== QsMenuButtonType.None || String(entry.icon || "") !== "");
    }

    function entryContentWidth(entry) {
        if (entry === null || entry === undefined || entry.isSeparator === true)
            return 0;

        var width = root.visualInset * 2 + root.rowPadding * 2 + Math.ceil(menuFontMetrics.advanceWidth(String(entry.text || "")));
        if (root.hasLeadingContent)
            width += root.leadingSlotWidth + Shell.Theme.spacingSmall;
        if (entry.hasChildren === true)
            width += Shell.Theme.spacingSmall + root.trailingSlotWidth;
        return width;
    }

    function widestEntryContentWidth() {
        var widest = root.visualInset * 2 + root.rowPadding * 2 + Math.ceil(menuFontMetrics.advanceWidth("No actions"));
        for (var index = 0; index < root.entries.length; index += 1)
            widest = Math.max(widest, root.entryContentWidth(root.entries[index]));
        return widest;
    }

    function headerContentWidth() {
        if (root.menuStack.length === 0)
            return 0;
        return root.visualInset * 2 + root.rowPadding * 2 + root.leadingSlotWidth + Shell.Theme.spacingSmall + Math.ceil(headerFontMetrics.advanceWidth(root.currentTitle));
    }

    function updatePlacement() {
        if (root.anchorItem === null || root.anchorItem === undefined || root.width <= 0 || root.height <= 0)
            return;

        var anchorBottom = root.anchorItem.mapToItem(null, root.anchorItem.width / 2, root.anchorItem.height);
        var margin = Shell.Theme.spacingLarge;
        var availableRight = Math.max(margin, root.width - margin - root.desiredPopupWidth);
        root.menuX = Math.max(margin, Math.min(availableRight, anchorBottom.x - root.desiredPopupWidth / 2));

        var belowBar = Math.max(root.barHeight + Shell.Theme.spacingXSmall, anchorBottom.y + Shell.Theme.spacingXSmall);
        root.menuY = Math.max(root.barHeight + Shell.Theme.spacingXSmall, Math.min(belowBar, root.height - margin - root.desiredPopupHeight));
    }

    function firstSelectableIndex() {
        for (var index = 0; index < root.entries.length; index += 1) {
            if (root.isSelectable(root.entries[index]))
                return index;
        }
        return -1;
    }

    function syncSelection() {
        if (!root.isSelectable(root.entryAt(root.selectedIndex)))
            root.selectedIndex = root.firstSelectableIndex();
        if (root.selectedIndex >= 0)
            menuList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
    }

    function moveSelection(delta) {
        if (root.entries.length === 0)
            return;

        var index = root.selectedIndex;
        for (var step = 0; step < root.entries.length; step += 1) {
            index = (index + delta + root.entries.length) % root.entries.length;
            if (root.isSelectable(root.entries[index])) {
                root.selectedIndex = index;
                menuList.positionViewAtIndex(index, ListView.Contain);
                return;
            }
        }
    }

    function openAt(menuHandle, item) {
        if (menuHandle === null || menuHandle === undefined || item === null || item === undefined)
            return;

        releaseTimer.stop();
        root.lifecycleSerial += 1;
        root.anchorItem = item;
        root.topLevelMenu = menuHandle;
        root.currentMenu = menuHandle;
        root.currentTitle = "";
        root.menuStack = [];
        menuOpener.menu = menuHandle;
        root.selectedIndex = -1;
        root.visible = true;
        Qt.callLater(root.finishOpen, root.lifecycleSerial);
    }

    function finishOpen(serial) {
        if (serial !== root.lifecycleSerial || !root.visible)
            return;
        root.updatePlacement();
        root.syncSelection();
        menuList.forceActiveFocus();
    }

    function dismiss() {
        root.visible = false;
    }

    function enterSubmenu(entry) {
        if (!root.isSelectable(entry) || entry.hasChildren !== true)
            return;

        var nextStack = root.menuStack.slice();
        nextStack.push({
            handle: root.currentMenu,
            title: root.currentTitle
        });
        root.menuStack = nextStack;
        root.currentMenu = entry;
        root.currentTitle = entry.text || "";
        menuOpener.menu = entry;
        root.selectedIndex = -1;
        Qt.callLater(root.syncSelection);
    }

    function leaveSubmenu() {
        if (root.menuStack.length === 0) {
            root.dismiss();
            return;
        }

        var nextStack = root.menuStack.slice();
        var parentMenu = nextStack.pop();
        root.menuStack = nextStack;
        root.currentMenu = parentMenu.handle;
        root.currentTitle = parentMenu.title;
        menuOpener.menu = parentMenu.handle;
        root.selectedIndex = -1;
        Qt.callLater(root.syncSelection);
    }

    function activateEntry(entry) {
        if (!root.isSelectable(entry))
            return;
        if (entry.hasChildren === true) {
            root.enterSubmenu(entry);
            return;
        }

        root.dismiss();
        if (typeof entry.triggered === "function")
            entry.triggered();
    }

    function activateSelected() {
        root.activateEntry(root.entryAt(root.selectedIndex));
    }

    function releaseIfClosed(serial) {
        if (serial !== root.lifecycleSerial || root.visible)
            return;
        menuOpener.menu = null;
        root.topLevelMenu = null;
        root.currentMenu = null;
        root.currentTitle = "";
        root.menuStack = [];
        root.selectedIndex = -1;
    }

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    visible: false
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.namespace: "funforgiven:tray-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        item: Rectangle {
            y: root.barHeight
            width: root.width
            height: Math.max(0, root.height - y)
        }
    }

    onEntriesChanged: Qt.callLater(root.syncSelection)
    onDesiredPopupWidthChanged: if (visible)
        Qt.callLater(root.updatePlacement)
    onDesiredPopupHeightChanged: if (visible)
        Qt.callLater(root.updatePlacement)
    onWidthChanged: if (visible)
        Qt.callLater(root.updatePlacement)
    onHeightChanged: if (visible)
        Qt.callLater(root.updatePlacement)
    onScreenChanged: if (visible)
        Qt.callLater(root.updatePlacement)
    onVisibleChanged: {
        if (visible) {
            root.announcedOpen = true;
            return;
        }
        if (!root.announcedOpen)
            return;

        root.announcedOpen = false;
        root.lifecycleSerial += 1;
        root.menuDismissed();
        releaseTimer.restart();
    }

    Timer {
        id: releaseTimer

        interval: 0
        repeat: false
        onTriggered: root.releaseIfClosed(root.lifecycleSerial)
    }

    FontMetrics {
        id: menuFontMetrics

        font.family: Shell.Theme.sansFont
        font.pixelSize: Shell.Theme.desktopFontSize
    }

    FontMetrics {
        id: headerFontMetrics

        font.family: Shell.Theme.sansFont
        font.pixelSize: Shell.Theme.labelFontSize
        font.weight: Font.DemiBold
    }

    QsMenuOpener {
        id: menuLifetime

        menu: root.topLevelMenu
    }

    QsMenuOpener {
        id: menuOpener
    }

    MouseArea {
        y: root.barHeight
        width: parent.width
        height: Math.max(0, parent.height - y)
        z: -1
        enabled: root.visible
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: root.dismiss()
    }

    Item {
        id: menuFrame

        x: root.menuX
        y: root.menuY
        width: root.desiredPopupWidth
        height: root.desiredPopupHeight
        z: 1

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: mouse => mouse.accepted = true
        }

        Components.Surface {
            anchors.fill: parent
            elevated: true
            radius: Shell.Theme.radiusMedium
            outlineColor: Shell.Theme.outlineStrong
            outlineWidth: Shell.Theme.outlineWidth

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.outerPadding
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    implicitHeight: root.headerHeight
                    visible: root.menuStack.length > 0

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: root.visualInset
                        color: backPointer.containsMouse ? Shell.Theme.hoverSurface : "transparent"
                        radius: Shell.Theme.radiusSmall

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: root.rowPadding
                            anchors.rightMargin: root.rowPadding
                            spacing: Shell.Theme.spacingSmall

                            Text {
                                text: "‹"
                                color: Shell.Theme.primaryText
                                font.family: Shell.Theme.sansFont
                                font.pixelSize: Shell.Theme.titleFontSize
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.currentTitle
                                color: Shell.Theme.primaryText
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                                font.family: Shell.Theme.sansFont
                                font.pixelSize: Shell.Theme.labelFontSize
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    MouseArea {
                        id: backPointer

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.leaveSubmenu()
                    }
                }

                ListView {
                    id: menuList

                    Layout.fillWidth: true
                    Layout.preferredHeight: root.desiredListHeight
                    clip: true
                    model: menuOpener.children
                    currentIndex: root.selectedIndex
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick
                    activeFocusOnTab: true

                    Accessible.name: "Tray menu"
                    Accessible.role: Accessible.PopupMenu

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Left) {
                            root.leaveSubmenu();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            root.moveSelection(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            root.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                            root.activateSelected();
                            event.accepted = true;
                        }
                    }

                    delegate: Item {
                        id: menuEntryDelegate

                        required property var modelData
                        required property int index

                        width: ListView.view.width
                        height: modelData.isSeparator ? Shell.Theme.spacingSmall : root.interactiveRowHeight

                        Accessible.name: modelData.isSeparator ? "Separator" : modelData.text
                        Accessible.role: modelData.isSeparator ? Accessible.Separator : (modelData.buttonType === QsMenuButtonType.CheckBox ? Accessible.CheckBox : (modelData.buttonType === QsMenuButtonType.RadioButton ? Accessible.RadioButton : Accessible.MenuItem))
                        Accessible.checked: modelData.checkState === Qt.Checked
                        Accessible.onPressAction: root.activateEntry(menuEntryDelegate.modelData)

                        Rectangle {
                            visible: menuEntryDelegate.modelData.isSeparator
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Shell.Theme.spacingSmall
                            anchors.rightMargin: Shell.Theme.spacingSmall
                            height: 1
                            color: Shell.Theme.border
                        }

                        Rectangle {
                            visible: !menuEntryDelegate.modelData.isSeparator
                            anchors.fill: parent
                            anchors.margins: root.visualInset
                            color: entryPointer.pressed ? Shell.Theme.pressedSurface : ((entryPointer.containsMouse || root.selectedIndex === menuEntryDelegate.index) ? Shell.Theme.hoverSurface : "transparent")
                            radius: Shell.Theme.radiusSmall

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: root.rowPadding
                                anchors.rightMargin: root.rowPadding
                                spacing: Shell.Theme.spacingSmall

                                Item {
                                    id: indicatorSlot

                                    visible: root.hasLeadingContent
                                    Layout.preferredWidth: Shell.Theme.iconMediumSize
                                    Layout.preferredHeight: Shell.Theme.iconMediumSize

                                    readonly property int buttonType: menuEntryDelegate.modelData.buttonType
                                    readonly property bool checked: menuEntryDelegate.modelData.checkState === Qt.Checked

                                    IconImage {
                                        visible: parent.buttonType === QsMenuButtonType.None && menuEntryDelegate.modelData.icon !== ""
                                        anchors.fill: parent
                                        source: menuEntryDelegate.modelData.icon
                                        mipmap: true
                                    }

                                    Rectangle {
                                        visible: parent.buttonType === QsMenuButtonType.CheckBox
                                        anchors.centerIn: parent
                                        width: 16
                                        height: 16
                                        radius: 4
                                        color: parent.checked ? Shell.Theme.systemAccent : "transparent"
                                        border.width: Shell.Theme.outlineWidth
                                        border.color: parent.checked ? Shell.Theme.systemAccent : Shell.Theme.secondaryText

                                        Text {
                                            visible: indicatorSlot.checked
                                            anchors.centerIn: parent
                                            text: "✓"
                                            color: Shell.Theme.accentText
                                            font.family: Shell.Theme.sansFont
                                            font.pixelSize: Shell.Theme.captionFontSize
                                            font.weight: Font.Bold
                                        }
                                    }

                                    Rectangle {
                                        visible: parent.buttonType === QsMenuButtonType.RadioButton
                                        anchors.centerIn: parent
                                        width: 16
                                        height: 16
                                        radius: 8
                                        color: "transparent"
                                        border.width: Shell.Theme.outlineWidth
                                        border.color: parent.checked ? Shell.Theme.systemAccent : Shell.Theme.secondaryText

                                        Rectangle {
                                            visible: indicatorSlot.checked
                                            anchors.centerIn: parent
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: Shell.Theme.systemAccent
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: menuEntryDelegate.modelData.text || ""
                                    color: menuEntryDelegate.modelData.enabled ? Shell.Theme.primaryText : Shell.Theme.secondaryText
                                    opacity: menuEntryDelegate.modelData.enabled ? 1 : Shell.Theme.disabledOpacity
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignLeft
                                    verticalAlignment: Text.AlignVCenter
                                    font.family: Shell.Theme.sansFont
                                    font.pixelSize: Shell.Theme.desktopFontSize
                                }

                                Text {
                                    visible: menuEntryDelegate.modelData.hasChildren
                                    text: "›"
                                    color: Shell.Theme.secondaryText
                                    font.family: Shell.Theme.sansFont
                                    font.pixelSize: Shell.Theme.titleFontSize
                                }
                            }

                            Components.FocusRing {
                                active: menuList.activeFocus && root.selectedIndex === menuEntryDelegate.index
                                ringRadius: Shell.Theme.radiusSmall
                            }
                        }

                        MouseArea {
                            id: entryPointer

                            anchors.fill: parent
                            enabled: root.isSelectable(menuEntryDelegate.modelData)
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onEntered: root.selectedIndex = menuEntryDelegate.index
                            onClicked: root.activateEntry(menuEntryDelegate.modelData)
                        }
                    }

                    Text {
                        visible: root.entries.length === 0
                        anchors.centerIn: parent
                        text: "No actions"
                        color: Shell.Theme.secondaryText
                        font.family: Shell.Theme.sansFont
                        font.pixelSize: Shell.Theme.desktopFontSize
                    }
                }
            }
        }
    }
}
