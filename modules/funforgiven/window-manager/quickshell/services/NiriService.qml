pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "NiriProtocol.js" as NiriProtocol
import "NiriState.js" as NiriState

QtObject {
    id: root

    readonly property string socketPath: Quickshell.env("NIRI_SOCKET")
    readonly property int maximumLineLength: 8 * 1024 * 1024

    readonly property var workspaces: root._view.workspaces
    readonly property var windows: root._view.windows
    readonly property bool connected: root._view.connected
    readonly property bool stale: root._view.stale
    readonly property bool configLoaded: root._view.configLoaded
    readonly property bool configFailed: root._view.configFailed
    readonly property string error: root._view.error || ""
    readonly property int generation: root._view.generation
    readonly property var focusedWorkspaceId: root._focusedId(root.workspaces)
    readonly property var focusedWindowId: root._focusedId(root.windows)

    readonly property bool actionBusy: root._actionQueue.length > 0
    readonly property string actionError: root._actionError

    signal actionSucceeded(string actionName)
    signal actionFailed(string actionName, string message)

    property var _state: NiriState.createState()
    property var _view: NiriState.publish(root._state)
    property bool _componentReady: false
    property int _eventReconnectAttempt: 0
    property string _eventDisconnectReason: ""
    property bool _eventGenerationHealthy: false

    property var _actionQueue: []
    property bool _actionInFlight: false
    property string _actionError: ""
    property int _actionReconnectAttempt: 0
    property string _actionDisconnectReason: ""
    property bool _resettingActionTransport: false

    function _sameId(left, right) {
        return left !== null && left !== undefined && right !== null && right !== undefined && typeof left === typeof right && String(left) === String(right);
    }

    function _focusedId(items) {
        for (var index = 0; index < items.length; index += 1) {
            if (items[index].is_focused === true) {
                return items[index].id;
            }
        }
        return null;
    }

    function _publish() {
        root._view = NiriState.publish(root._state);
    }

    function workspacesForOutput(outputName) {
        var result = [];
        for (var index = 0; index < root.workspaces.length; index += 1) {
            if (root.workspaces[index].output === outputName) {
                result.push(root.workspaces[index]);
            }
        }
        return result;
    }

    function windowsForWorkspace(workspaceId) {
        var result = [];
        for (var index = 0; index < root.windows.length; index += 1) {
            if (root._sameId(root.windows[index].workspace_id, workspaceId)) {
                result.push(root.windows[index]);
            }
        }
        return result;
    }

    function activeWorkspaceForOutput(outputName) {
        var outputWorkspaces = root.workspacesForOutput(outputName);
        for (var index = 0; index < outputWorkspaces.length; index += 1) {
            if (outputWorkspaces[index].is_active === true) {
                return outputWorkspaces[index];
            }
        }
        return null;
    }

    function _handleEventConnected() {
        root._eventReconnectTimer.stop();
        root._eventInitialStateTimer.restart();
        root._eventDisconnectReason = "";
        root._eventGenerationHealthy = false;
        root._state = NiriState.connectionOpened(root._state);
        root._publish();

        root._eventSocket.write(JSON.stringify(NiriProtocol.eventStream()) + "\n");
        root._eventSocket.flush();
    }

    function _markEventDisconnected(message) {
        root._eventInitialStateTimer.stop();
        root._eventGenerationHealthy = false;
        root._abortActionQueue("niri event state became stale: " + message);
        if (root._state.connected || !root._state.stale || root._state.error !== message) {
            root._state = NiriState.connectionClosed(root._state, message);
            root._publish();
        }
        root._scheduleEventReconnect();
    }

    function _disconnectEvent(message) {
        if (root._eventDisconnectReason.length === 0) {
            root._eventDisconnectReason = message;
        }
        var wasConnected = root._eventSocket.connected;
        root._eventSocket.connected = false;
        if (!wasConnected && root._componentReady) {
            var reason = root._eventDisconnectReason;
            root._eventDisconnectReason = "";
            root._markEventDisconnected(reason);
        }
    }

    function _scheduleEventReconnect() {
        if (!root._componentReady || root.socketPath.length === 0 || root._eventReconnectTimer.running) {
            return;
        }

        var delay = Math.min(8000, 250 * Math.pow(2, root._eventReconnectAttempt));
        root._eventReconnectAttempt = Math.min(6, root._eventReconnectAttempt + 1);
        root._eventReconnectTimer.interval = delay;
        root._eventReconnectTimer.start();
    }

    function _handleEventLine(line) {
        if (line.length === 0) {
            return;
        }

        if (line.length > root.maximumLineLength) {
            root._disconnectEvent("niri event exceeded the input limit");
            return;
        }

        var message;
        try {
            message = JSON.parse(line);
        } catch (parseError) {
            root._disconnectEvent("could not parse niri event JSON: " + parseError);
            return;
        }

        if (message !== null && typeof message === "object" && Object.prototype.hasOwnProperty.call(message, "Err")) {
            root._disconnectEvent("niri rejected EventStream: " + message.Err);
            return;
        }

        var next = NiriState.reduce(root._state, message);
        if (next !== root._state) {
            root._state = next;
            root._publish();
            if (!root._eventGenerationHealthy && root.connected && !root.stale) {
                root._eventGenerationHealthy = true;
                root._eventReconnectAttempt = 0;
                root._eventInitialStateTimer.stop();
            }
        }
    }

    function _rejectAction(actionName, message) {
        root._actionError = message;
        root.actionFailed(actionName, message);
        return false;
    }

    function _abortActionQueue(message) {
        root._actionReconnectTimer.stop();
        root._actionReplyTimer.stop();
        root._actionReconnectAttempt = 0;
        root._actionDisconnectReason = "";

        root._resettingActionTransport = true;
        root._actionSocket.connected = false;
        root._resettingActionTransport = false;

        var abandoned = root._actionQueue;
        root._actionQueue = [];
        root._actionInFlight = false;
        if (abandoned.length === 0) {
            return;
        }

        root._actionError = message;
        for (var index = 0; index < abandoned.length; index += 1) {
            root.actionFailed(abandoned[index].name, message);
        }
    }

    function _enqueueAction(actionName, request) {
        if (request === null) {
            return root._rejectAction(actionName, "invalid niri action argument");
        }
        if (!root.connected || root.stale) {
            return root._rejectAction(actionName, "niri event state is not live");
        }

        root._actionError = "";
        root._actionQueue = root._actionQueue.concat([
            {
                name: actionName,
                request: request
            }
        ]);
        root._driveActionQueue();
        return true;
    }

    function focusWorkspace(id) {
        return root._enqueueAction("focus-workspace", NiriProtocol.focusWorkspace(id));
    }

    function focusWindow(id) {
        return root._enqueueAction("focus-window", NiriProtocol.focusWindow(id));
    }

    function focusMonitor(output) {
        return root._enqueueAction("focus-monitor", NiriProtocol.focusMonitor(output));
    }

    function _driveActionQueue() {
        if (root._actionQueue.length === 0 || root._actionInFlight) {
            return;
        }
        if (!root.connected || root.stale) {
            root._abortActionQueue("niri event state is not live");
            return;
        }

        if (!root._actionSocket.connected) {
            root._actionSocket.connected = true;
            return;
        }

        root._actionInFlight = true;
        root._actionReplyTimer.restart();
        root._actionSocket.write(JSON.stringify(root._actionQueue[0].request) + "\n");
        root._actionSocket.flush();
    }

    function _dropCurrentAction(message) {
        if (root._actionQueue.length === 0) {
            root._actionInFlight = false;
            return;
        }

        var actionName = root._actionQueue[0].name;
        root._actionQueue = root._actionQueue.slice(1);
        root._actionInFlight = false;
        root._actionError = message;
        root.actionFailed(actionName, message);
    }

    function _finishCurrentAction(result) {
        if (!root._actionInFlight || root._actionQueue.length === 0) {
            return;
        }

        root._actionReplyTimer.stop();
        var actionName = root._actionQueue[0].name;
        root._actionQueue = root._actionQueue.slice(1);
        root._actionInFlight = false;

        if (result.ok) {
            root._actionError = "";
            root.actionSucceeded(actionName);
        } else {
            root._actionError = result.error;
            root.actionFailed(actionName, result.error);
        }

        root._driveActionQueue();
    }

    function _handleActionLine(line) {
        if (!root._actionInFlight) {
            return;
        }

        if (line.length > root.maximumLineLength) {
            root._disconnectAction("niri action reply exceeded the input limit");
            return;
        }

        var reply;
        try {
            reply = JSON.parse(line);
        } catch (parseError) {
            root._disconnectAction("could not parse niri action reply: " + parseError);
            return;
        }

        root._finishCurrentAction(NiriProtocol.replyResult(reply));
    }

    function _scheduleActionReconnect() {
        if (!root.connected || root.stale || root._actionQueue.length === 0 || root._actionReconnectTimer.running) {
            return;
        }

        var delay = Math.min(4000, 250 * Math.pow(2, root._actionReconnectAttempt));
        root._actionReconnectAttempt = Math.min(5, root._actionReconnectAttempt + 1);
        root._actionReconnectTimer.interval = delay;
        root._actionReconnectTimer.start();
    }

    function _handleActionDisconnected() {
        if (!root._componentReady) {
            return;
        }
        var message = root._actionDisconnectReason || "niri action socket disconnected before its reply";
        root._actionDisconnectReason = "";
        root._actionReplyTimer.stop();
        if (root._actionInFlight) {
            root._dropCurrentAction(message);
        }
        root._scheduleActionReconnect();
    }

    function _disconnectAction(message) {
        if (root._actionDisconnectReason.length === 0) {
            root._actionDisconnectReason = message;
        }
        var wasConnected = root._actionSocket.connected;
        root._actionSocket.connected = false;
        if (!wasConnected) {
            root._handleActionDisconnected();
        }
    }

    property Socket _eventSocket: Socket {
        path: root.socketPath
        connected: false

        parser: SplitParser {
            splitMarker: "\n"
            maximumBufferSize: root.maximumLineLength
            onRead: line => root._handleEventLine(line)
            onBufferLimitExceeded: size => root._disconnectEvent("niri event buffer exceeded the input limit (" + size + " bytes)")
        }

        onConnectedChanged: {
            if (connected) {
                root._handleEventConnected();
            } else if (root._componentReady) {
                var message = root._eventDisconnectReason || "niri event socket disconnected";
                root._eventDisconnectReason = "";
                root._markEventDisconnected(message);
            }
        }
    }

    property Socket _actionSocket: Socket {
        path: root.socketPath
        connected: false

        parser: SplitParser {
            splitMarker: "\n"
            maximumBufferSize: root.maximumLineLength
            onRead: line => root._handleActionLine(line)
            onBufferLimitExceeded: size => root._disconnectAction("niri action reply buffer exceeded the input limit (" + size + " bytes)")
        }

        onConnectedChanged: {
            if (root._resettingActionTransport) {
                return;
            }
            if (connected) {
                root._actionReconnectTimer.stop();
                root._actionReconnectAttempt = 0;
                root._actionDisconnectReason = "";
                root._driveActionQueue();
            } else {
                root._handleActionDisconnected();
            }
        }
    }

    property Connections _eventSocketErrors: Connections {
        target: null
        ignoreUnknownSignals: true
        function onError() {
            root._disconnectEvent("niri event socket error");
        }
    }

    property Connections _actionSocketErrors: Connections {
        target: null
        ignoreUnknownSignals: true
        function onError() {
            root._disconnectAction("niri action socket error");
        }
    }

    property Timer _eventReconnectTimer: Timer {
        repeat: false
        onTriggered: root._eventSocket.connected = true
    }

    property Timer _eventInitialStateTimer: Timer {
        interval: 5000
        repeat: false
        onTriggered: root._disconnectEvent("timed out waiting for niri initial state")
    }

    property Timer _actionReconnectTimer: Timer {
        repeat: false
        onTriggered: root._driveActionQueue()
    }

    property Timer _actionReplyTimer: Timer {
        interval: 5000
        repeat: false
        onTriggered: {
            root._disconnectAction("timed out waiting for niri action reply");
        }
    }

    Component.onCompleted: {
        root._componentReady = true;
        root._eventSocketErrors.target = root._eventSocket;
        root._actionSocketErrors.target = root._actionSocket;
        if (root.socketPath.length === 0) {
            root._markEventDisconnected("NIRI_SOCKET is not set");
        } else {
            root._eventSocket.connected = true;
        }
    }

    Component.onDestruction: {
        root._componentReady = false;
        root._eventReconnectTimer.stop();
        root._eventInitialStateTimer.stop();
        root._actionReconnectTimer.stop();
        root._actionReplyTimer.stop();
        root._eventSocket.connected = false;
        root._actionSocket.connected = false;
    }
}
