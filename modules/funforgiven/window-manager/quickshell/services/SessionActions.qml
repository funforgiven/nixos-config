pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import ".." as Shell
import "SessionCommand.js" as SessionCommand

QtObject {
    id: root

    readonly property int confirmationTimeoutMs: 5000
    readonly property bool busy: root.activeAction.length > 0
    property string armedAction: ""
    property string activeAction: ""
    property string failedAction: ""
    property string error: ""
    property var _process: null

    signal actionStarted(string action)
    signal actionSucceeded(string action)
    signal actionFailed(string action, string message)

    function _label(action) {
        if (action === "logout")
            return "log out";
        if (action === "reboot")
            return "restart";
        return "shut down";
    }

    function _clearFailure() {
        root.failedAction = "";
        root.error = "";
    }

    function cancelConfirmation() {
        confirmationTimer.stop();
        root.armedAction = "";
    }

    function _fail(action, message) {
        var detail = String(message || "").trim() || `Could not ${root._label(action)}`;
        root.activeAction = "";
        root.failedAction = action;
        root.error = detail;
        root.actionFailed(action, detail);
    }

    function _succeed(action) {
        root.activeAction = "";
        root._clearFailure();
        root.actionSucceeded(action);
    }

    function _startLogout() {
        root.activeAction = "logout";
        root.actionStarted("logout");
        var accepted = NiriService.quit(true);
        if (!accepted && root.activeAction === "logout") {
            root._fail("logout", NiriService.actionError || "Niri did not accept the logout request");
        }
        return accepted;
    }

    function _startSystemAction(action) {
        var command;
        try {
            command = SessionCommand.systemctl(Shell.ShellConfig.systemctl, action);
        } catch (commandError) {
            root._fail(action, commandError);
            return false;
        }

        var process = processComponent.createObject(root, {
            actionName: action,
            command: command
        });
        if (process === null) {
            root._fail(action, `Could not create the ${root._label(action)} request`);
            return false;
        }

        root._process = process;
        root.activeAction = action;
        root.actionStarted(action);
        process.running = true;
        return true;
    }

    function _confirmOrRun(action) {
        if (root.busy)
            return false;

        if (root.armedAction !== action) {
            root._clearFailure();
            root.armedAction = action;
            confirmationTimer.restart();
            return true;
        }

        root.cancelConfirmation();
        root._clearFailure();
        return action === "logout" ? root._startLogout() : root._startSystemAction(action);
    }

    function requestLogout() {
        return root._confirmOrRun("logout");
    }

    function requestReboot() {
        return root._confirmOrRun("reboot");
    }

    function requestPoweroff() {
        return root._confirmOrRun("poweroff");
    }

    function _disposeProcess(process) {
        if (root._process === process)
            root._process = null;
        process.completed = true;
        process.destroy();
    }

    function _processFailedToStart(process) {
        if (root._process !== process || process.completed)
            return;
        var action = process.actionName;
        root._disposeProcess(process);
        root._fail(action, `Could not start the ${root._label(action)} request`);
    }

    function _processExited(process, exitCode) {
        if (root._process !== process || process.completed)
            return;

        var action = process.actionName;
        var detail = String(process.errorText || process.outputText || "").trim();
        root._disposeProcess(process);
        if (exitCode === 0) {
            root._succeed(action);
        } else {
            root._fail(action, detail || `${root._label(action)} request exited with code ${exitCode}`);
        }
    }

    property Timer _confirmationTimer: Timer {
        id: confirmationTimer

        interval: root.confirmationTimeoutMs
        repeat: false
        onTriggered: root.armedAction = ""
    }

    property Connections _niriActions: Connections {
        target: NiriService

        function onActionSucceeded(actionName) {
            if (actionName === "quit" && root.activeAction === "logout")
                root._succeed("logout");
        }

        function onActionFailed(actionName, message) {
            if (actionName === "quit" && root.activeAction === "logout")
                root._fail("logout", message);
        }
    }

    property Component _processComponent: Component {
        id: processComponent

        Process {
            id: childProcess

            property string actionName: ""
            property alias outputText: outputCollector.text
            property alias errorText: errorCollector.text
            property bool startedSuccessfully: false
            property bool completed: false

            stdout: StdioCollector {
                id: outputCollector
            }
            stderr: StdioCollector {
                id: errorCollector
            }

            onStarted: startedSuccessfully = true

            onRunningChanged: {
                if (!running && !startedSuccessfully && !completed) {
                    Qt.callLater(function () {
                        if (!childProcess.running && !childProcess.startedSuccessfully && !childProcess.completed)
                            root._processFailedToStart(childProcess);
                    });
                }
            }

            onExited: function (exitCode) { // qmllint disable signal-handler-parameters
                root._processExited(childProcess, exitCode);
            }
        }
    }
}
