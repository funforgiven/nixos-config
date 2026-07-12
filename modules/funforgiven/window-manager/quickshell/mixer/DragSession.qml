pragma ComponentBehavior: Bound

import QtQuick
import ".." as Shell
import "../components" as Components
import "DragModel.js" as DragModel

Item {
    id: root

    property bool active: false
    property var dragPayload: null
    property string sourceChannelId: ""
    property string sourceKey: ""
    property int currentToken: 0
    property int nextToken: 1
    property string title: ""
    property string detail: ""
    property url iconSource: ""
    property color accent: Shell.Theme.systemAccent

    function placePointer(pointerItem, pointerX, pointerY) {
        if (!pointerItem)
            return false;

        var position = pointerItem.mapToItem(root, Number(pointerX), Number(pointerY));
        if (!position || !isFinite(position.x) || !isFinite(position.y))
            return false;

        dragProxy.x = position.x - dragProxy.width / 2;
        dragProxy.y = position.y - dragProxy.height / 2;

        var gap = Shell.Theme.spacingMedium;
        var avatarX = position.x + gap;
        var avatarY = position.y + gap;
        if (avatarX + avatar.width > root.width)
            avatarX = position.x - avatar.width - gap;
        if (avatarY + avatar.height > root.height)
            avatarY = position.y - avatar.height - gap;
        avatar.x = Math.max(0, Math.min(Math.max(0, root.width - avatar.width), avatarX));
        avatar.y = Math.max(0, Math.min(Math.max(0, root.height - avatar.height), avatarY));
        return true;
    }

    function begin(sourceItem, pointerItem, pointerX, pointerY, payload, nextTitle, nextDetail, nextIcon, nextAccent, nextSourceKey) {
        if (!sourceItem || !pointerItem || active)
            return 0;

        var normalizedPayload = DragModel.normalizePayload(payload);
        if (normalizedPayload === null)
            return 0;

        avatar.width = Math.max(220, Math.min(300, sourceItem.width));
        if (!placePointer(pointerItem, pointerX, pointerY))
            return 0;

        var token = nextToken;
        nextToken += 1;
        currentToken = token;
        dragPayload = normalizedPayload;
        sourceChannelId = String(normalizedPayload.sourceChannelId || "");
        sourceKey = String(nextSourceKey || "");
        title = String(nextTitle || "Audio stream");
        detail = String(nextDetail || "");
        iconSource = nextIcon || "";
        accent = nextAccent || Shell.Theme.systemAccent;
        active = true;
        dragProxy.Drag.active = true;
        return token;
    }

    function updatePointer(token, pointerItem, pointerX, pointerY) {
        if (!active || Number(token) !== currentToken)
            return false;
        return placePointer(pointerItem, pointerX, pointerY);
    }

    function finish(token, cancelled) {
        if (!active || Number(token) !== currentToken)
            return false;
        if (cancelled)
            dragProxy.Drag.cancel();
        else
            dragProxy.Drag.drop();

        active = false;
        dragPayload = null;
        sourceChannelId = "";
        sourceKey = "";
        currentToken = 0;
        title = "";
        detail = "";
        iconSource = "";
        dragProxy.x = 0;
        dragProxy.y = 0;
        avatar.x = 0;
        avatar.y = 0;
        return true;
    }

    function cancel(token) {
        var requestedToken = token === undefined || token === null ? currentToken : Number(token);
        return finish(requestedToken, true);
    }

    anchors.fill: parent
    z: 1000

    Component.onDestruction: cancel()

    Item {
        id: dragProxy

        width: 1
        height: 1
        visible: root.active
        opacity: 0

        Drag.active: false
        Drag.source: root
        Drag.keys: ["funforgiven.audio.stream"]
        Drag.supportedActions: Qt.MoveAction
        Drag.proposedAction: Qt.MoveAction
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
    }

    Components.DragAvatar {
        id: avatar

        title: root.title
        detail: root.detail
        iconSource: root.iconSource
        accent: root.accent
        visible: root.active
    }
}
