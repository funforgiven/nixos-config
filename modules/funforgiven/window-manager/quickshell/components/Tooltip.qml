// Delayed popup presentation and anchor-relative placement are adapted from
// noctalia-dev's MIT-licensed tooltip at commit
// a48885b9fec485c903c955749a7da6e30147cd38. See THIRD_PARTY_NOTICES.md.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import ".." as Shell

Item {
    id: root

    property string text: ""
    property int delay: 500
    property int timeout: 6000
    property int maximumWidth: 320
    property int gap: Shell.Theme.spacingXSmall
    property Item anchorItem: parent

    visible: false
    implicitWidth: 0
    implicitHeight: 0

    function hideNow() {
        showTimer.stop();
        timeoutTimer.stop();
        tooltipWindow.visible = false;
    }

    function syncPresentation() {
        showTimer.stop();

        if (!root.visible || root.text.length === 0 || root.anchorItem === null) {
            hideNow();
            return;
        }

        if (tooltipWindow.visible) {
            if (root.timeout > 0)
                timeoutTimer.restart();
            return;
        }

        showTimer.interval = Math.max(0, root.delay);
        showTimer.restart();
    }

    onVisibleChanged: syncPresentation()
    onTextChanged: syncPresentation()
    onAnchorItemChanged: syncPresentation()

    Component.onCompleted: syncPresentation()
    Component.onDestruction: hideNow()

    Text {
        id: textMeasure

        visible: false
        text: root.text
        font.family: Shell.Theme.sansFont
        font.pixelSize: Shell.Theme.desktopFontSize
    }

    Timer {
        id: showTimer

        repeat: false
        onTriggered: {
            if (!root.visible || root.text.length === 0 || root.anchorItem === null)
                return;
            tooltipWindow.visible = true;
            if (root.timeout > 0) {
                timeoutTimer.interval = root.timeout;
                timeoutTimer.restart();
            }
        }
    }

    Timer {
        id: timeoutTimer

        repeat: false
        onTriggered: tooltipWindow.visible = false
    }

    PopupWindow {
        id: tooltipWindow

        anchor {
            item: root.anchorItem
            edges: Edges.Bottom // qmllint disable missing-type
            gravity: Edges.Bottom // qmllint disable missing-type
            adjustment: PopupAdjustment.FlipY | PopupAdjustment.Slide | PopupAdjustment.Resize // qmllint disable missing-type

            margins {
                top: -root.gap
                bottom: -root.gap
            }
        }

        visible: false
        grabFocus: false
        color: "transparent"
        mask: Region {}
        implicitWidth: Math.max(1, Math.ceil(Math.min(root.maximumWidth, textMeasure.implicitWidth + Shell.Theme.spacingMedium * 2)))
        implicitHeight: Math.max(1, Math.ceil(tooltipText.implicitHeight + Shell.Theme.spacingSmall * 2))

        Rectangle {
            anchors.fill: parent
            color: Shell.Theme.raisedSurface
            radius: Shell.Theme.radiusSmall
            border.color: Shell.Theme.border
            border.width: Shell.Theme.outlineWidth

            Text {
                id: tooltipText

                anchors.fill: parent
                anchors.leftMargin: Shell.Theme.spacingMedium
                anchors.rightMargin: Shell.Theme.spacingMedium
                anchors.topMargin: Shell.Theme.spacingSmall
                anchors.bottomMargin: Shell.Theme.spacingSmall
                color: Shell.Theme.primaryText
                text: root.text
                font.family: Shell.Theme.sansFont
                font.pixelSize: Shell.Theme.desktopFontSize
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
