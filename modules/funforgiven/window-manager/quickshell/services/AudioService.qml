pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Services.Pipewire
import ".." as Shell
import "../mixer/AudioModel.js" as AudioModel

QtObject {
    id: root

    property var channels: []
    property var physicalOutputs: []
    property var unroutedGroups: []
    property var playbackStreams: []
    property string observedDefaultChannelId: ""
    property bool defaultWarning: false
    property int revision: 0
    property string _snapshotSignature: ""
    readonly property bool ready: Pipewire.ready
    readonly property int graphSettleMs: 24

    function _nodeRecord(node) {
        if (!node) {
            return null;
        }
        return {
            ref: node,
            id: node.id,
            name: node.name,
            description: node.description,
            nickname: node.nickname,
            type: node.type,
            isSink: node.isSink,
            isStream: node.isStream,
            ready: node.ready,
            routeAvailable: node.routeAvailable,
            audio: node.audio,
            properties: node.ready ? node.properties : ({})
        };
    }

    function _linkRecord(link) {
        if (!link || !link.source || !link.target) {
            return null;
        }
        return {
            ref: link,
            sourceId: link.source.id,
            targetId: link.target.id,
            usable: link.state !== PwLinkState.Error && link.state !== PwLinkState.Unlinked
        };
    }

    function _resolvePresentation(node) {
        try {
            var result = AppService.resolveStream(node);
            if (result) {
                return result;
            }
        } catch (error) {
            console.warn("AudioService could not resolve stream identity:", error);
        }
        return {
            canonicalId: "pipewire:" + String(node.id),
            displayName: "",
            iconPath: Quickshell.iconPath("application-x-executable")
        };
    }

    function rebuild() {
        var nodes = Pipewire.nodes.values.map(_nodeRecord).filter(function (node) {
            return node !== null;
        });
        var links = Pipewire.linkGroups.values.map(_linkRecord).filter(function (link) {
            return link !== null;
        });
        var defaultId = Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.id : null;
        var snapshot = AudioModel.buildSnapshot(Shell.ShellConfig.audioChannels, nodes, links, PwNodeType.AudioOutStream, PwNodeType.AudioSink, defaultId, _resolvePresentation, Pipewire.ready);
        var signature = AudioModel.snapshotSignature(snapshot);
        if (signature === _snapshotSignature)
            return;

        _snapshotSignature = signature;
        channels = snapshot.channels;
        physicalOutputs = snapshot.physicalOutputs;
        unroutedGroups = snapshot.unroutedGroups;
        playbackStreams = snapshot.playbackStreams;
        observedDefaultChannelId = snapshot.observedDefaultChannelId || "";
        defaultWarning = snapshot.defaultWarning;
        revision += 1;
    }

    function scheduleRebuild() {
        rebuildTimer.restart();
    }

    function channel(channelId) {
        for (var index = 0; index < channels.length; index += 1) {
            if (channels[index].id === channelId) {
                return channels[index];
            }
        }
        return null;
    }

    function stream(streamId, streamSerial) {
        for (var index = 0; index < playbackStreams.length; index += 1) {
            var candidate = playbackStreams[index];
            if (String(candidate.id) === String(streamId) && String(candidate.serial) === String(streamSerial)) {
                return candidate;
            }
        }
        return null;
    }

    function isLivePlaybackStream(streamId, streamSerial) {
        return stream(streamId, streamSerial) !== null;
    }

    function channelIdForStream(streamId, streamSerial) {
        var candidate = stream(streamId, streamSerial);
        return candidate ? candidate.channelId : null;
    }

    function outputIdForChannel(channelId) {
        var candidate = channel(channelId);
        return candidate && candidate.output ? candidate.output.id : null;
    }

    function outputsForChannel(channelId) {
        return physicalOutputs.filter(function (output) {
            return output.safeFor.indexOf(channelId) !== -1;
        });
    }

    function isLiveOutput(outputId, outputSerial, channelId) {
        return physicalOutputs.some(function (output) {
            return AudioModel.isSelectableOutput(output, outputId, outputSerial, channelId);
        });
    }

    Component.onCompleted: scheduleRebuild()

    property Timer _rebuildTimer: Timer {
        id: rebuildTimer
        interval: root.graphSettleMs
        repeat: false
        onTriggered: root.rebuild()
    }

    property PwObjectTracker _objectTracker: PwObjectTracker {
        objects: Pipewire.nodes.values.concat(Pipewire.linkGroups.values)
    }

    property Connections _nodeModelConnections: Connections {
        target: Pipewire.nodes

        function onValuesChanged() {
            root.scheduleRebuild();
        }
    }

    property Connections _linkModelConnections: Connections {
        target: Pipewire.linkGroups

        function onValuesChanged() {
            root.scheduleRebuild();
        }
    }

    property Connections _pipewireConnections: Connections {
        target: Pipewire

        function onDefaultAudioSinkChanged() {
            root.scheduleRebuild();
        }

        function onReadyChanged() {
            root.scheduleRebuild();
        }
    }

    property Connections _appServiceConnections: Connections {
        target: AppService

        function onRevisionChanged() {
            root.scheduleRebuild();
        }
    }

    property Instantiator _nodeObservers: Instantiator {
        model: Pipewire.nodes

        delegate: QtObject {
            id: nodeObserver
            required property var modelData

            property Connections _nodeConnections: Connections {
                target: nodeObserver.modelData

                function onPropertiesChanged() {
                    root.scheduleRebuild();
                }

                function onReadyChanged() {
                    root.scheduleRebuild();
                }

                function onRouteAvailabilityChanged() {
                    root.scheduleRebuild();
                }
            }
        }
    }

    property Instantiator _linkObservers: Instantiator {
        model: Pipewire.linkGroups

        delegate: QtObject {
            id: linkObserver
            required property var modelData

            property Connections _linkConnections: Connections {
                target: linkObserver.modelData

                function onStateChanged() {
                    root.scheduleRebuild();
                }
            }
        }
    }
}
