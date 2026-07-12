pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import ".." as Shell
import "../components" as Components

Item {
    id: root

    required property var parentWindow
    signal menuOpening

    property var menuItem: null
    property Item menuAnchorItem: null

    implicitWidth: trayRow.implicitWidth
    implicitHeight: Shell.Theme.controlCompactSize

    function hasUsableMenu(item, anchorItem) {
        return item !== null && anchorItem !== null && item.hasMenu === true;
    }

    function showMenu(item, anchorItem) {
        if (!root.hasUsableMenu(item, anchorItem))
            return;

        if (trayMenu.visible && item === root.menuItem) {
            trayMenu.dismiss();
            return;
        }

        root.menuOpening();
        root.menuItem = item;
        root.menuAnchorItem = anchorItem;
        trayMenu.openAt(item.menu, anchorItem);
    }

    function clearMenuForAnchor(anchorItem) {
        if (root.menuAnchorItem !== anchorItem)
            return;
        if (trayMenu.visible)
            trayMenu.dismiss();
        else {
            root.menuItem = null;
            root.menuAnchorItem = null;
        }
    }

    function handleMenuDismissed() {
        root.menuItem = null;
        root.menuAnchorItem = null;
    }

    function dismissMenu() {
        if (trayMenu.visible)
            trayMenu.dismiss();
    }

    TrayMenu {
        id: trayMenu

        screen: root.parentWindow.screen
        barHeight: root.parentWindow.height
        onMenuDismissed: root.handleMenuDismissed()
    }

    Row {
        id: trayRow

        anchors.fill: parent
        spacing: Shell.Theme.spacingXSmall / 2

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: trayDelegate

                required property var modelData

                readonly property var trayItem: modelData
                readonly property bool needsAttention: trayItem.status === Status.NeedsAttention
                readonly property bool passive: trayItem.status === Status.Passive
                readonly property string tooltipText: {
                    const title = trayItem.tooltipTitle || trayItem.title || trayItem.id || "Tray item";
                    return trayItem.tooltipDescription ? `${title}\n${trayItem.tooltipDescription}` : title;
                }

                function showMenu() {
                    root.showMenu(trayItem, trayDelegate);
                }

                Component.onDestruction: root.clearMenuForAnchor(trayDelegate)

                width: Shell.Theme.controlCompactSize
                height: root.height
                opacity: passive ? 0.5 : 1

                Accessible.name: tooltipText
                Accessible.description: root.menuItem === trayItem && trayMenu.visible ? "Menu open" : (trayItem.onlyMenu ? "Opens menu" : "Application status item")
                Accessible.role: Accessible.Button
                Accessible.onPressAction: {
                    if (trayDelegate.trayItem.onlyMenu)
                        trayDelegate.showMenu();
                    else
                        trayDelegate.trayItem.activate();
                }

                Rectangle {
                    anchors.fill: parent
                    color: trayDelegate.needsAttention ? Shell.Theme.errorSurface : (trayPointer.pressed ? Shell.Theme.pressedSurface : (trayPointer.containsMouse ? Shell.Theme.hoverSurface : "transparent"))
                    radius: Shell.Theme.radiusSmall
                    border.color: trayDelegate.needsAttention ? Shell.Theme.error : "transparent"
                    border.width: trayDelegate.needsAttention ? Shell.Theme.outlineWidth : 0

                    Behavior on color {
                        ColorAnimation {
                            duration: Shell.Theme.animationFast
                            easing.type: Shell.Theme.easingStandard
                        }
                    }
                }

                IconImage {
                    anchors.centerIn: parent
                    width: Shell.Theme.iconMediumSize
                    height: Shell.Theme.iconMediumSize
                    source: trayDelegate.trayItem.icon
                    mipmap: true
                }

                Rectangle {
                    visible: trayDelegate.needsAttention
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 4
                    width: 5
                    height: 5
                    radius: 3
                    color: Shell.Theme.error
                }

                MouseArea {
                    id: trayPointer

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) {
                            trayDelegate.trayItem.secondaryActivate();
                        } else if (mouse.button === Qt.RightButton || trayDelegate.trayItem.onlyMenu) {
                            trayDelegate.showMenu();
                        } else {
                            trayDelegate.trayItem.activate();
                        }
                    }
                    onWheel: wheel => {
                        const horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y);
                        const angled = horizontal ? wheel.angleDelta.x : wheel.angleDelta.y;
                        const pixel = horizontal ? wheel.pixelDelta.x : wheel.pixelDelta.y;
                        trayDelegate.trayItem.scroll(Math.round(angled !== 0 ? angled : pixel), horizontal);
                        wheel.accepted = true;
                    }
                }

                Components.Tooltip {
                    visible: trayPointer.containsMouse && !(root.menuItem === trayDelegate.trayItem && trayMenu.visible)
                    text: trayDelegate.tooltipText
                }
            }
        }
    }
}
