pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import ".." as Shell
import "AudioRouting.js" as AudioRouting

QtObject {
    id: root

    property var pendingStreams: ({})
    property var streamErrors: ({})
    property var pendingChannels: ({})
    property var channelErrors: ({})
    property var recentErrors: []
    property var _operations: ({})
    property int _nextRequestId: 1
    readonly property int helperCommandTimeoutMs: 12000
    readonly property int graphConfirmationTimeoutMs: 6000
    readonly property bool hasPendingOperations: Object.keys(_operations).length > 0
    readonly property int pendingOperationCount: Object.keys(_operations).length

    function _copyMap(source) {
        var target = {};
        Object.keys(source).forEach(function (key) {
            target[key] = source[key];
        });
        return target;
    }

    function _streamKey(streamId, streamSerial) {
        return String(streamId) + ":" + String(streamSerial);
    }

    function _setStreamPending(key, details) {
        var next = _copyMap(pendingStreams);
        if (details) {
            next[key] = details;
        } else {
            delete next[key];
        }
        pendingStreams = next;
    }

    function _setStreamError(key, message) {
        var next = _copyMap(streamErrors);
        if (message) {
            next[key] = message;
        } else {
            delete next[key];
        }
        streamErrors = next;
    }

    function _setChannelPending(channelId, details) {
        var next = _copyMap(pendingChannels);
        if (details) {
            next[channelId] = details;
        } else {
            delete next[channelId];
        }
        pendingChannels = next;
    }

    function _setChannelError(channelId, message) {
        var next = _copyMap(channelErrors);
        if (message) {
            next[channelId] = message;
        } else {
            delete next[channelId];
        }
        channelErrors = next;
    }

    function streamState(streamId, streamSerial) {
        var key = _streamKey(streamId, streamSerial);
        return {
            pending: pendingStreams[key] || null,
            error: streamErrors[key] || ""
        };
    }

    function channelState(channelId) {
        return {
            pending: pendingChannels[channelId] || null,
            error: channelErrors[channelId] || ""
        };
    }

    function dismissStreamError(streamId, streamSerial) {
        _setStreamError(_streamKey(streamId, streamSerial), "");
    }

    function dismissChannelError(channelId) {
        _setChannelError(channelId, "");
    }

    function clearRecentErrors() {
        recentErrors = [];
    }

    function _recordError(operation, message) {
        var context = operation.kind === "stream" ? (operation.canonicalId || "Audio stream") : (operation.channelId + " channel");
        var next = [
            {
                context: context,
                message: message,
                requestId: operation.requestId
            }
        ].concat(recentErrors);
        recentErrors = next.slice(0, 8);
    }

    function _preflightError(operation, message) {
        operation.requestId = "preflight-" + String(_nextRequestId++);
        _recordError(operation, message);
        if (operation.kind === "stream" && operation.key) {
            _setStreamError(operation.key, message);
        } else if (operation.kind === "channel" && operation.channelId) {
            _setChannelError(operation.channelId, message);
        }
        return false;
    }

    function _dropErrorsForEndedStreams() {
        var next = _copyMap(streamErrors);
        var changed = false;
        Object.keys(next).forEach(function (key) {
            var separator = key.lastIndexOf(":");
            var streamId = key.slice(0, separator);
            var streamSerial = key.slice(separator + 1);
            if (!AudioService.isLivePlaybackStream(streamId, streamSerial)) {
                delete next[key];
                changed = true;
            }
        });
        if (changed) {
            streamErrors = next;
        }
    }

    function _newRequest(operation) {
        var requestId = String(_nextRequestId++);
        var operations = _copyMap(_operations);
        operation.requestId = requestId;
        operation.deadline = Date.now() + helperCommandTimeoutMs;
        operation.phase = "command";
        operations[requestId] = operation;
        _operations = operations;

        var process = processComponent.createObject(root, {
            requestId: requestId
        });
        if (!process) {
            _fail(requestId, "Could not start the audio routing helper");
            return false;
        }
        operation.process = process;
        process.command = operation.command;
        process.running = true;
        return true;
    }

    function _removeOperation(requestId) {
        var operations = _copyMap(_operations);
        delete operations[requestId];
        _operations = operations;
    }

    function _disposeProcess(operation) {
        if (!operation || !operation.process) {
            return;
        }
        var process = operation.process;
        operation.process = null;
        if (process.running) {
            process.running = false;
        }
        process.destroy();
    }

    function _succeed(requestId) {
        var operation = _operations[requestId];
        if (!operation) {
            return;
        }
        if (operation.kind === "stream") {
            _setStreamPending(operation.key, null);
            _setStreamError(operation.key, "");
        } else {
            _setChannelPending(operation.channelId, null);
            _setChannelError(operation.channelId, "");
        }
        _removeOperation(requestId);
    }

    function _fail(requestId, message) {
        var operation = _operations[requestId];
        if (!operation) {
            return;
        }
        root._disposeProcess(operation);
        _recordError(operation, message);
        if (operation.kind === "stream") {
            _setStreamPending(operation.key, null);
            _setStreamError(operation.key, message);
        } else {
            _setChannelPending(operation.channelId, null);
            _setChannelError(operation.channelId, message);
        }
        _removeOperation(requestId);
    }

    function _processExited(requestId, exitCode, errorText) {
        var operation = _operations[requestId];
        if (!operation) {
            return;
        }
        root._disposeProcess(operation);
        if (exitCode !== 0) {
            var detail = String(errorText || "").trim();
            _fail(requestId, detail || "Audio routing helper exited with code " + exitCode);
            return;
        }

        if (operation.action === "forget") {
            _succeed(requestId);
            return;
        }
        operation.phase = "graph";
        operation.deadline = Date.now() + graphConfirmationTimeoutMs;
        _reconcile(requestId);
    }

    function _reconcile(requestId) {
        var operation = _operations[requestId];
        if (!operation || operation.phase !== "graph") {
            return;
        }

        if (operation.kind === "stream") {
            var stream = AudioService.stream(operation.streamId, operation.streamSerial);
            if (!stream) {
                return;
            } else if (stream.channelId === operation.channelId) {
                _succeed(requestId);
            }
            return;
        }

        var channel = AudioService.channel(operation.channelId);
        if (!channel || !channel.bridge || String(channel.bridgeId) !== String(operation.bridgeId) || String(channel.bridgeSerial) !== String(operation.bridgeSerial)) {
            _fail(requestId, "The channel bridge changed before its output was confirmed");
        } else if (channel.output && String(channel.output.id) === String(operation.outputId) && String(channel.output.serial) === String(operation.outputSerial)) {
            _succeed(requestId);
        }
    }

    function moveSelection(selection, channelId) {
        var normalized = AudioRouting.normalizeSelection(selection);
        if (normalized === null) {
            return _preflightError({
                kind: "channel",
                channelId: channelId || "Unknown"
            }, "The playback selection was invalid; refresh the mixer and retry");
        }

        var resolved = AudioRouting.resolveSelection(normalized, AudioService.playbackStreams);
        if (resolved.length === 0) {
            var selectedStream = normalized.kind === "stream" ? normalized.stream : null;
            return _preflightError({
                kind: selectedStream ? "stream" : "channel",
                channelId: channelId || "Unknown",
                canonicalId: selectedStream ? selectedStream.canonicalId : "",
                key: selectedStream ? _streamKey(selectedStream.id, selectedStream.serial) : ""
            }, normalized.kind === "group" ? "The selected application has no live playback streams" : "The selected playback stream is no longer live");
        }
        return _moveResolvedStreams(resolved, channelId);
    }

    function moveGroup(persistentKey, channelId) {
        return moveSelection(AudioRouting.groupSelection(persistentKey), channelId);
    }

    function moveStream(streamRef, channelId) {
        return moveSelection(AudioRouting.streamSelection(streamRef), channelId);
    }

    function movePayload(payload, channelId) {
        return moveSelection(payload ? payload.selection : null, channelId);
    }

    function moveStreams(streamRefs, channelId) {
        var selection = AudioRouting.referencesSelection(streamRefs);
        if (selection === null) {
            return _preflightError({
                kind: "channel",
                channelId: channelId || "Unknown"
            }, "No playback streams were supplied for routing");
        }
        return moveSelection(selection, channelId);
    }

    function _moveResolvedStreams(streamRefs, channelId) {
        if (!Array.isArray(streamRefs) || streamRefs.length === 0) {
            return _preflightError({
                kind: "channel",
                channelId: channelId || "Unknown"
            }, "No playback streams were supplied for routing");
        }
        if (!AudioService.channel(channelId)) {
            return _preflightError({
                kind: "channel",
                channelId: channelId || "Unknown"
            }, "The destination channel is no longer available");
        }

        var seenStreamRefs = Object.create(null);
        var uniqueStreamRefs = streamRefs.filter(function (streamRef) {
            if (!streamRef || streamRef.id === null || streamRef.id === undefined || streamRef.serial === null || streamRef.serial === undefined)
                return false;
            var key = _streamKey(streamRef.id, streamRef.serial);
            if (seenStreamRefs[key])
                return false;
            seenStreamRefs[key] = true;
            return true;
        });
        if (uniqueStreamRefs.length === 0) {
            return _preflightError({
                kind: "channel",
                channelId: channelId
            }, "No valid playback stream identities were supplied for routing");
        }
        var live = uniqueStreamRefs.filter(function (streamRef) {
            return streamRef && AudioService.isLivePlaybackStream(streamRef.id, streamRef.serial) && !pendingStreams[_streamKey(streamRef.id, streamRef.serial)];
        });
        var skipped = uniqueStreamRefs.length - live.length;
        if (skipped > 0) {
            var preflightOperation = {
                kind: "stream",
                canonicalId: live.length > 0 ? live[0].canonicalId : (streamRefs[0] && streamRefs[0].canonicalId),
                key: streamRefs[0] ? _streamKey(streamRefs[0].id, streamRefs[0].serial) : ""
            };
            var preflightMessage = live.length === 0 ? "No grouped streams remain live and idle" : skipped + (skipped === 1 ? " stream ended or was already moving; routing the remaining live members" : " streams ended or were already moving; routing the remaining live members");
            if (live.length === 0) {
                return _preflightError(preflightOperation, preflightMessage);
            }
            preflightOperation.requestId = "preflight-" + String(_nextRequestId++);
            _recordError(preflightOperation, preflightMessage);
        }

        var actionable = live.filter(function (streamRef) {
            var observed = AudioService.stream(streamRef.id, streamRef.serial);
            return observed && String(observed.channelId || "") !== String(channelId);
        });
        if (actionable.length === 0) {
            return true;
        }
        live = actionable;

        live.forEach(function (streamRef) {
            var key = _streamKey(streamRef.id, streamRef.serial);
            _setStreamError(key, "");
            _setStreamPending(key, {
                action: "move",
                channelId: channelId,
                label: "Moving to " + channelId + "…"
            });
            _newRequest({
                kind: "stream",
                action: "move",
                key: key,
                streamId: streamRef.id,
                streamSerial: streamRef.serial,
                canonicalId: streamRef.canonicalId,
                channelId: channelId,
                command: [Shell.ShellConfig.audioController, "move-stream", String(streamRef.id), String(streamRef.serial), channelId]
            });
        });
        return true;
    }

    function moveBridge(channelId, outputId, outputSerial) {
        var channel = AudioService.channel(channelId);
        if (!channel || !channel.bridge) {
            return _preflightError({
                kind: "channel",
                channelId: channelId || "Unknown"
            }, "The channel bridge is no longer available");
        }
        if (pendingChannels[channelId]) {
            return _preflightError({
                kind: "channel",
                channelId: channelId
            }, "Another output action is still pending");
        }
        if (!AudioService.isLiveOutput(outputId, outputSerial, channelId)) {
            return _preflightError({
                kind: "channel",
                channelId: channelId
            }, "The selected hardware output is no longer available or cycle-safe");
        }

        _setChannelError(channelId, "");
        _setChannelPending(channelId, {
            action: "move-output",
            outputId: outputId,
            label: "Switching output…"
        });
        return _newRequest({
            kind: "channel",
            action: "move-output",
            channelId: channelId,
            bridgeId: channel.bridgeId,
            bridgeSerial: channel.bridgeSerial,
            outputId: outputId,
            outputSerial: outputSerial,
            command: [Shell.ShellConfig.audioController, "move-bridge", String(channel.bridgeId), String(channel.bridgeSerial), channelId, String(outputId), String(outputSerial)]
        });
    }

    function forgetBridgeTarget(channelId) {
        var channel = AudioService.channel(channelId);
        if (!channel || !channel.bridge) {
            return _preflightError({
                kind: "channel",
                channelId: channelId || "Unknown"
            }, "The channel bridge is no longer available");
        }
        if (pendingChannels[channelId]) {
            return _preflightError({
                kind: "channel",
                channelId: channelId
            }, "Another output action is still pending");
        }

        _setChannelError(channelId, "");
        _setChannelPending(channelId, {
            action: "forget",
            label: "Forgetting saved output…"
        });
        return _newRequest({
            kind: "channel",
            action: "forget",
            channelId: channelId,
            bridgeId: channel.bridgeId,
            bridgeSerial: channel.bridgeSerial,
            command: [Shell.ShellConfig.audioController, "forget-bridge-target", String(channel.bridgeId), String(channel.bridgeSerial), channelId]
        });
    }

    function setChannelVolume(channelId, requestedVolume) {
        var channel = AudioService.channel(channelId);
        var volume = Math.max(0, Math.min(1, Number(requestedVolume)));
        if (!channel || !channel.bridge || !channel.bridge.audio || !isFinite(volume)) {
            _setChannelError(channelId, "Channel gain is unavailable");
            return false;
        }
        channel.bridge.audio.volume = volume;
        return true;
    }

    function setChannelMuted(channelId, muted) {
        var channel = AudioService.channel(channelId);
        if (!channel || !channel.bridge || !channel.bridge.audio) {
            _setChannelError(channelId, "Channel mute control is unavailable");
            return false;
        }
        channel.bridge.audio.muted = muted === true;
        return true;
    }

    property Connections _audioServiceConnections: Connections {
        target: AudioService

        function onRevisionChanged() {
            Object.keys(root._operations).forEach(function (requestId) {
                root._reconcile(requestId);
            });
            root._dropErrorsForEndedStreams();
        }
    }

    property Timer _timeoutTimer: Timer {
        interval: 200
        repeat: true
        running: root.hasPendingOperations

        onTriggered: {
            var now = Date.now();
            Object.keys(root._operations).forEach(function (requestId) {
                var operation = root._operations[requestId];
                if (operation && now >= operation.deadline) {
                    root._fail(requestId, operation.phase === "graph" ? "PipeWire did not confirm the requested graph change" : "The audio routing helper timed out");
                }
            });
        }
    }

    property Component _processComponent: Component {
        id: processComponent

        Process {
            id: childProcess
            property string requestId: ""
            property alias errorText: errorCollector.text
            property bool startedSuccessfully: false

            stdout: StdioCollector {}
            stderr: StdioCollector {
                id: errorCollector
            }

            onStarted: startedSuccessfully = true

            onRunningChanged: {
                if (!running && !startedSuccessfully) {
                    var failedRequestId = requestId;
                    Qt.callLater(function () {
                        var operation = root._operations[failedRequestId];
                        if (operation && operation.process === childProcess && !childProcess.running && !childProcess.startedSuccessfully) {
                            root._fail(failedRequestId, "The audio routing helper could not be started");
                        }
                    });
                }
            }

            onExited: function (exitCode) { // qmllint disable signal-handler-parameters
                root._processExited(requestId, exitCode, errorText);
            }
        }
    }
}
