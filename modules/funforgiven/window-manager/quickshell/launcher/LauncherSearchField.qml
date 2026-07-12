import QtQuick
import QtQuick.Layouts
import Quickshell
import ".." as Shell
import "../components" as Components

Rectangle {
    id: root

    property alias text: searchInput.text
    readonly property bool inputFocused: searchInput.activeFocus
    readonly property bool hovered: fieldHover.hovered

    signal edited
    signal navigationKey(var event)

    function focusInput(): void {
        searchInput.forceActiveFocus();
    }

    implicitHeight: 56
    radius: height / 2
    color: inputFocused ? Shell.Theme.selectedSurface : (hovered ? Shell.Theme.hoverSurface : Shell.Theme.baseSurface)
    border.width: inputFocused ? Shell.Theme.focusRingWidth : Shell.Theme.outlineWidth
    border.color: inputFocused ? Shell.Theme.systemAccent : Shell.Theme.outlineStrong

    Behavior on color {
        ColorAnimation {
            duration: Shell.Theme.animationFast
            easing.type: Shell.Theme.easingStandard
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: Shell.Theme.animationFast
            easing.type: Shell.Theme.easingStandard
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Shell.Theme.spacingMedium
        anchors.rightMargin: Shell.Theme.spacingSmall
        spacing: Shell.Theme.spacingMedium

        Rectangle {
            Layout.preferredWidth: Shell.Theme.controlCompactSize
            Layout.preferredHeight: Shell.Theme.controlCompactSize
            radius: Shell.Theme.radiusPill
            color: root.inputFocused ? Qt.rgba(Shell.Theme.systemAccent.r, Shell.Theme.systemAccent.g, Shell.Theme.systemAccent.b, Shell.Theme.selectedOverlayOpacity) : "transparent"

            Components.AppIcon {
                anchors.centerIn: parent
                width: 22
                height: 22
                iconSize: 22
                source: Quickshell.iconPath("system-search", "edit-find")
                accessibleName: "Search"
                Accessible.ignored: true
            }
        }

        TextInput {
            id: searchInput

            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Shell.Theme.primaryText
            selectionColor: Shell.Theme.systemAccent
            selectedTextColor: Shell.Theme.accentText
            clip: true
            verticalAlignment: TextInput.AlignVCenter
            font.family: Shell.Theme.sansFont
            font.pixelSize: Shell.Theme.bodyFontSize
            activeFocusOnTab: true

            Accessible.name: "Search apps"
            Accessible.description: "Filter installed apps"
            Accessible.role: Accessible.EditableText

            onTextEdited: root.edited()
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: event => root.navigationKey(event)

            Text {
                anchors.fill: parent
                visible: searchInput.text.length === 0
                text: "Search apps"
                color: Shell.Theme.secondaryText
                verticalAlignment: Text.AlignVCenter
                font: searchInput.font
            }
        }

        Components.IconButton {
            visible: root.text.length > 0
            enabled: visible
            Layout.preferredWidth: Shell.Theme.controlCompactSize
            Layout.preferredHeight: Shell.Theme.controlCompactSize
            iconSource: Quickshell.iconPath("edit-clear-symbolic", "edit-clear")
            accessibleName: "Clear search"
            tooltipText: "Clear"
            onClicked: {
                root.text = "";
                root.edited();
                root.focusInput();
            }
        }
    }

    HoverHandler {
        id: fieldHover
    }
}
