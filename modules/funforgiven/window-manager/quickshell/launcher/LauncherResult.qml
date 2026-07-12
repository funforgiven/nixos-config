// Pointer-selection behavior adapted from the MIT-licensed legacy-v4 snapshot
// a48885b9fec485c903c955749a7da6e30147cd38; see THIRD_PARTY_NOTICES.md.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".." as Shell
import "../components" as Components

Components.Surface {
    id: root

    required property var application
    required property int resultIndex
    property bool pending: false
    property bool failed: false
    readonly property string detailText: application.genericName || ""

    signal activated
    signal pointerMoved(int resultIndex, real sceneX, real sceneY)

    height: 72
    interactive: true
    hovered: rowHover.hovered
    pressed: rowTap.pressed
    accent: failed ? Shell.Theme.error : Shell.Theme.systemAccent
    surfaceColor: "transparent"
    outlineColor: failed ? Shell.Theme.error : Shell.Theme.outline
    outlineWidth: selected || failed ? Shell.Theme.outlineWidth : 0
    scale: rowTap.pressed ? 0.99 : 1
    transformOrigin: Item.Center

    Behavior on scale {
        NumberAnimation {
            duration: Shell.Theme.animationFast
            easing.type: Shell.Theme.easingStandard
        }
    }

    Accessible.name: application.name
    Accessible.description: pending ? "Starting" : (failed ? "Launch failed" : "Open app")
    Accessible.role: Accessible.Button
    Accessible.onPressAction: root.activated()

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Shell.Theme.spacingSmall
        anchors.rightMargin: Shell.Theme.spacingMedium
        spacing: Shell.Theme.spacingMedium

        Rectangle {
            Layout.preferredWidth: 4
            Layout.preferredHeight: 36
            radius: Shell.Theme.radiusPill
            color: root.accent
            opacity: root.selected || root.failed ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Shell.Theme.animationFast
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            radius: Shell.Theme.radiusMedium
            color: root.selected ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, Shell.Theme.selectedOverlayOpacity) : (root.hovered ? Shell.Theme.elevatedSurface : Shell.Theme.raisedSurface)
            border.width: root.selected ? Shell.Theme.outlineWidth : 0
            border.color: root.accent

            Behavior on color {
                ColorAnimation {
                    duration: Shell.Theme.animationFast
                    easing.type: Shell.Theme.easingStandard
                }
            }

            Components.AppIcon {
                anchors.centerIn: parent
                width: 38
                height: 38
                iconSize: 36
                source: root.application.iconPath
                accessibleName: root.application.name
                Accessible.ignored: true
                opacity: root.pending ? Shell.Theme.disabledOpacity : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Shell.Theme.animationFast
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.application.name
                color: Shell.Theme.primaryText
                elide: Text.ElideRight
                font.family: Shell.Theme.sansFont
                font.pixelSize: Shell.Theme.bodyFontSize
                font.weight: root.selected ? Font.DemiBold : Font.Medium
            }

            Text {
                Layout.fillWidth: true
                visible: root.detailText.length > 0
                text: root.detailText
                color: Shell.Theme.secondaryText
                elide: Text.ElideRight
                font.family: Shell.Theme.sansFont
                font.pixelSize: Shell.Theme.captionFontSize
            }
        }

        Components.StatusChip {
            visible: root.pending || root.failed
            text: root.pending ? "Starting…" : "Failed"
            tone: root.failed ? "error" : "warning"
        }

        Rectangle {
            visible: root.selected && !root.pending && !root.failed
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: Shell.Theme.radiusPill
            color: Shell.Theme.selectedSurface

            Text {
                anchors.centerIn: parent
                text: "↵"
                color: Shell.Theme.primaryText
                font.family: Shell.Theme.monoFont
                font.pixelSize: Shell.Theme.labelFontSize
                font.weight: Font.DemiBold
                Accessible.ignored: true
            }
        }
    }

    TapHandler {
        id: rowTap

        acceptedButtons: Qt.LeftButton
        onTapped: root.activated()
    }

    HoverHandler {
        id: rowHover

        cursorShape: Qt.PointingHandCursor
        onPointChanged: root.pointerMoved(root.resultIndex, point.scenePosition.x, point.scenePosition.y)
    }
}
