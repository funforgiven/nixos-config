function owns(object, key) {
    return object !== null
        && typeof object === "object"
        && Object.prototype.hasOwnProperty.call(object, key);
}

function value(properties, key) {
    return properties && owns(properties, key) ? properties[key] : null;
}

function text(input) {
    if (input === null || input === undefined) {
        return "";
    }
    return String(input).trim();
}

function present(input) {
    return input !== null && input !== undefined && text(input) !== "";
}

function propertyIsTrue(input) {
    if (input === true || input === 1) {
        return true;
    }
    var normalized = text(input).toLowerCase();
    return normalized === "true" || normalized === "yes" || normalized === "1";
}

function sameId(left, right) {
    return left !== null
        && left !== undefined
        && right !== null
        && right !== undefined
        && String(left) === String(right);
}

function compareText(left, right) {
    left = text(left).toLocaleLowerCase();
    right = text(right).toLocaleLowerCase();
    if (left < right) {
        return -1;
    }
    if (left > right) {
        return 1;
    }
    return 0;
}

function compareId(left, right) {
    var leftNumber = Number(left);
    var rightNumber = Number(right);
    if (isFinite(leftNumber) && isFinite(rightNumber) && leftNumber !== rightNumber) {
        return leftNumber - rightNumber;
    }
    return compareText(left, right);
}

function serial(node) {
    return node ? value(node.properties, "object.serial") : null;
}

function outputAvailable(node) {
    var properties = node && node.properties;
    return node !== null
        && node !== undefined
        && node.ready !== false
        && node.routeAvailable !== false
        && !propertyIsTrue(value(properties, "node.disabled"))
        && !propertyIsTrue(value(properties, "device.disabled"));
}

function outputRecord(node) {
    if (!node)
        return null;
    return {
        node: node.ref || null,
        id: node.id,
        serial: serial(node),
        name: node.name,
        label: text(node.description) || text(node.nickname) || text(node.name),
        available: outputAvailable(node)
    };
}

function hasRealApplicationIdentity(node) {
    var properties = node && node.properties;
    return present(value(properties, "application.id"))
        || present(value(properties, "application.name"))
        || present(value(properties, "application.process.binary"))
        || present(value(properties, "client.name"));
}

function isPlaybackStream(node, playbackType) {
    var properties = node && node.properties;
    var isOutputAudioStream = text(value(properties, "media.class")) === "Stream/Output/Audio";
    var classifiedAsStream = node && (node.isStream === true || node.type === playbackType);
    if (!node || !classifiedAsStream || !isOutputAudioStream || !hasRealApplicationIdentity(node)) {
        return false;
    }

    properties = properties || {};
    var kind = text(value(properties, "funforgiven.audio.kind"));
    var name = text(node.name);
    if (kind === "bridge" || kind === "sink") {
        return false;
    }
    if (propertyIsTrue(value(properties, "stream.monitor"))
            || propertyIsTrue(value(properties, "node.monitor"))
            || /(?:^|[._-])monitor(?:$|[._-])/i.test(name)) {
        return false;
    }
    return true;
}

function persistentIdentity(node) {
    var properties = node && node.properties;
    var mediaClass = text(value(properties, "media.class")).replace(/^Stream\//, "") || "Output/Audio";
    if (value(properties, "media.role") === "Notification") {
        return mediaClass + ":media.role:Notification";
    }
    var keys = [
        "application.id",
        "application.name",
        "media.name",
        "node.name"
    ];

    for (var index = 0; index < keys.length; index += 1) {
        var candidate = value(properties, keys[index]);
        if (candidate !== null && candidate !== undefined && candidate !== false) {
            return mediaClass + ":" + keys[index] + ":" + String(candidate);
        }
    }
    if (node && node.name !== null && node.name !== undefined) {
        return mediaClass + ":node.name:" + String(node.name);
    }
    return mediaClass + ":object.serial:" + text(serial(node) || node.id);
}

function streamLabel(node, presentation) {
    var properties = node.properties || {};
    var candidates = [
        value(properties, "application.name"),
        presentation && presentation.displayName,
        value(properties, "application.process.binary"),
        value(properties, "client.name"),
        value(properties, "media.name"),
        node.description,
        node.name
    ];

    for (var index = 0; index < candidates.length; index += 1) {
        if (present(candidates[index])) {
            return text(candidates[index]);
        }
    }
    return "Unknown application";
}

function childLabel(node) {
    var properties = node.properties || {};
    var role = text(value(properties, "media.role"));
    var media = text(value(properties, "media.name"));
    if (role && media && role.toLocaleLowerCase() !== media.toLocaleLowerCase()) {
        return role + " · " + media;
    }
    return role || media || text(node.description) || text(node.name) || "Audio stream";
}

function channelNode(definition, kind, nodes) {
    var expectedName = kind === "sink" ? definition.sinkName : definition.bridgeName;
    for (var index = 0; index < nodes.length; index += 1) {
        var node = nodes[index];
        var properties = node.properties || {};
        if (node.name === expectedName
                && text(value(properties, "funforgiven.audio.channel")) === definition.id
                && text(value(properties, "funforgiven.audio.kind")) === kind) {
            return node;
        }
    }
    return null;
}

function usableLinks(links) {
    return links.filter(function (link) {
        return link && link.usable !== false && link.sourceId !== undefined
            && link.targetId !== undefined;
    });
}

function channelIdsForStream(stream, channelNodes, links) {
    var matches = [];
    for (var linkIndex = 0; linkIndex < links.length; linkIndex += 1) {
        var link = links[linkIndex];
        for (var channelIndex = 0; channelIndex < channelNodes.length; channelIndex += 1) {
            var sink = channelNodes[channelIndex].sink;
            if (!sink) {
                continue;
            }

            var connected = (sameId(link.sourceId, stream.id) && sameId(link.targetId, sink.id))
                || (sameId(link.targetId, stream.id) && sameId(link.sourceId, sink.id));
            if (connected && matches.indexOf(channelNodes[channelIndex].id) === -1) {
                matches.push(channelNodes[channelIndex].id);
            }
        }
    }
    return matches;
}

function isReservedNode(node, definitions) {
    var properties = node.properties || {};
    if (present(value(properties, "funforgiven.audio.channel"))
            || present(value(properties, "funforgiven.audio.kind"))) {
        return true;
    }

    for (var index = 0; index < definitions.length; index += 1) {
        if (node.name === definitions[index].sinkName
                || node.name === definitions[index].bridgeName) {
            return true;
        }
    }
    return false;
}

function canonicalGlobalId(input) {
    var raw = text(input);
    if (!/^(0|[1-9][0-9]*)$/.test(raw)) {
        return null;
    }
    var number = Number(raw);
    return Number.isSafeInteger(number) && number <= 4294967294 ? raw : null;
}

function stableNameIsUnique(node, nodes) {
    if (!Array.isArray(nodes)) {
        return true;
    }
    var name = text(node && node.name);
    var matches = nodes.filter(function (candidate) {
        return candidate && (text(candidate.name) === name
            || text(value(candidate.properties, "object.path")) === name);
    });
    return matches.length === 1 && matches[0] === node;
}

function isPhysicalSink(node, audioSinkType, definitions, nodes) {
    var classifiedAsSink = node && (node.isSink === true || node.type === audioSinkType);
    if (!node || !classifiedAsSink || isReservedNode(node, definitions)) {
        return false;
    }

    var properties = node.properties || {};
    var name = text(node.name);
    if (text(value(properties, "media.class")) !== "Audio/Sink"
            || !present(name)
            || isFinite(Number(name))
            || canonicalGlobalId(value(properties, "device.id")) === null
            || propertyIsTrue(value(properties, "node.virtual"))
            || propertyIsTrue(value(properties, "wireplumber.is-virtual"))
            || propertyIsTrue(value(properties, "wireplumber.is-fallback"))
            || propertyIsTrue(value(properties, "bluez5.loopback"))
            || propertyIsTrue(value(properties, "stream.monitor"))
            || propertyIsTrue(value(properties, "node.monitor"))) {
        return false;
    }
    if (owns(properties, "node.link-group")
            || owns(properties, "filter.smart")
            || owns(properties, "filter.smart.name")
            || owns(properties, "filter.smart.target")
            || text(value(properties, "factory.name")) === "support.null-audio-sink") {
        return false;
    }
    if (/(?:^|[._-])monitor(?:$|[._-])/i.test(text(node.name))) {
        return false;
    }
    return present(serial(node)) && stableNameIsUnique(node, nodes);
}

function adjacency(links, channelNodes) {
    var result = Object.create(null);

    function add(source, target) {
        var key = String(source);
        if (!result[key]) {
            result[key] = [];
        }
        if (result[key].indexOf(String(target)) === -1) {
            result[key].push(String(target));
        }
    }

    links.forEach(function (link) {
        add(link.sourceId, link.targetId);
    });
    channelNodes.forEach(function (channel) {
        if (channel.sink && channel.bridge) {
            add(channel.sink.id, channel.bridge.id);
        }
    });
    return result;
}

function pathExists(graph, start, target) {
    var queue = [String(start)];
    var seen = Object.create(null);
    var wanted = String(target);

    while (queue.length > 0) {
        var current = queue.shift();
        if (current === wanted) {
            return true;
        }
        if (seen[current]) {
            continue;
        }
        seen[current] = true;
        var next = graph[current] || [];
        for (var index = 0; index < next.length; index += 1) {
            if (!seen[next[index]]) {
                queue.push(next[index]);
            }
        }
    }
    return false;
}

function wouldCreateCycle(bridge, candidate, graph) {
    return bridge && candidate && pathExists(graph, candidate.id, bridge.id);
}

function linkedPeer(node, links, nodes) {
    if (!node) {
        return { node: null, count: 0 };
    }

    var peerIds = [];
    links.forEach(function (link) {
        var peer = null;
        if (sameId(link.sourceId, node.id)) {
            peer = link.targetId;
        } else if (sameId(link.targetId, node.id)) {
            peer = link.sourceId;
        }
        if (peer !== null && peerIds.indexOf(String(peer)) === -1) {
            peerIds.push(String(peer));
        }
    });

    if (peerIds.length !== 1) {
        return { node: null, count: peerIds.length };
    }
    for (var index = 0; index < nodes.length; index += 1) {
        if (sameId(nodes[index].id, peerIds[0])) {
            return { node: nodes[index], count: 1 };
        }
    }
    return { node: null, count: 1 };
}

function groupStreams(streams) {
    var groups = Object.create(null);

    streams.forEach(function (stream) {
        var key = stream.persistentKey;
        if (!groups[key]) {
            groups[key] = {
                key: key,
                canonicalId: stream.canonicalId,
                displayName: stream.displayName,
                iconPath: stream.iconPath,
                streams: []
            };
        }
        groups[key].streams.push(stream);
    });

    return Object.keys(groups).map(function (key) {
        var group = groups[key];
        group.streams.sort(function (left, right) {
            return compareId(left.serial, right.serial)
                || compareId(left.id, right.id);
        });
        group.count = group.streams.length;
        return group;
    }).sort(function (left, right) {
        return compareText(left.key, right.key);
    });
}

function streamProjection(stream) {
    return [
        String(stream.id),
        String(stream.serial),
        text(stream.persistentKey),
        text(stream.canonicalId),
        text(stream.displayName),
        text(stream.childLabel),
        String(stream.iconPath || ""),
        Array.isArray(stream.memberships) ? stream.memberships.map(String) : [],
        stream.channelId === null || stream.channelId === undefined ? null : String(stream.channelId),
        text(stream.routingState)
    ];
}

function groupProjection(group) {
    return [
        text(group.key),
        text(group.canonicalId),
        text(group.displayName),
        String(group.iconPath || ""),
        Array.isArray(group.streams) ? group.streams.map(streamProjection) : []
    ];
}

function outputProjection(output) {
    if (!output)
        return null;
    return [
        String(output.id),
        String(output.serial),
        text(output.name),
        text(output.label),
        output.available === undefined ? null : output.available === true,
        Array.isArray(output.safeFor) ? output.safeFor.map(String) : [],
        output.isPhysical === undefined ? null : output.isPhysical === true,
        output.isCycleSafe === undefined ? null : output.isCycleSafe === true
    ];
}

function isSelectableOutput(output, outputId, outputSerial, channelId) {
    return output !== null
        && output !== undefined
        && output.available === true
        && sameId(output.id, outputId)
        && sameId(output.serial, outputSerial)
        && Array.isArray(output.safeFor)
        && output.safeFor.indexOf(channelId) !== -1;
}

function snapshotSignature(snapshot) {
    snapshot = snapshot || {};
    return JSON.stringify({
        channels: (snapshot.channels || []).map(function (channel) {
            return [
                text(channel.id),
                text(channel.label),
                channel.isDefault === true,
                channel.isObservedDefault === true,
                channel.sinkId === null || channel.sinkId === undefined ? null : String(channel.sinkId),
                channel.sinkSerial === null || channel.sinkSerial === undefined ? null : String(channel.sinkSerial),
                channel.bridgeId === null || channel.bridgeId === undefined ? null : String(channel.bridgeId),
                channel.bridgeSerial === null || channel.bridgeSerial === undefined ? null : String(channel.bridgeSerial),
                outputProjection(channel.output),
                channel.status ? [text(channel.status.state), text(channel.status.message)] : null,
                (channel.groups || []).map(groupProjection)
            ];
        }),
        physicalOutputs: (snapshot.physicalOutputs || []).map(outputProjection),
        unroutedGroups: (snapshot.unroutedGroups || []).map(groupProjection),
        playbackStreams: (snapshot.playbackStreams || []).map(streamProjection),
        observedDefaultChannelId: snapshot.observedDefaultChannelId || null,
        defaultWarning: snapshot.defaultWarning === true
    });
}

function channelStatus(channel, outputLink, output, graphReady) {
    if (graphReady === false) {
        return { state: "connecting", message: "Binding channel graph…" };
    }
    if (!channel.sink) {
        return { state: "error", message: "Logical sink is missing" };
    }
    if (!channel.bridge) {
        return { state: "error", message: "Aggregate output bridge is missing" };
    }
    if (channel.sink.ready === false || channel.bridge.ready === false) {
        return { state: "connecting", message: "Binding channel graph…" };
    }
    if (outputLink.count > 1) {
        return { state: "error", message: "Bridge has multiple live targets" };
    }
    if (!output) {
        return { state: "waiting", message: "Waiting for a physical output" };
    }
    if (!output.isPhysical) {
        return { state: "error", message: "Bridge target is not a safe hardware sink" };
    }
    if (!output.isCycleSafe) {
        return { state: "error", message: "Bridge target creates an audio feedback cycle" };
    }
    if (output.available !== true) {
        return { state: "waiting", message: "Hardware output is unavailable" };
    }
    return { state: "connected", message: "Connected" };
}

function buildSnapshot(definitions, nodes, rawLinks, playbackType, audioSinkType,
                       defaultSinkId, resolvePresentation, graphReady) {
    definitions = Array.isArray(definitions) ? definitions : [];
    nodes = Array.isArray(nodes) ? nodes : [];
    var links = usableLinks(Array.isArray(rawLinks) ? rawLinks : []);

    var channelNodes = definitions.map(function (definition) {
        return {
            id: definition.id,
            definition: definition,
            sink: channelNode(definition, "sink", nodes),
            bridge: channelNode(definition, "bridge", nodes)
        };
    });
    var graph = adjacency(links, channelNodes);

    var outputs = nodes.filter(function (node) {
        return isPhysicalSink(node, audioSinkType, definitions, nodes);
    }).map(function (node) {
        var output = outputRecord(node);
        output.safeFor = channelNodes.filter(function (channel) {
            return channel.bridge && !wouldCreateCycle(channel.bridge, node, graph);
        }).map(function (channel) {
            return channel.id;
        });
        return output;
    }).sort(function (left, right) {
        return compareText(left.name, right.name)
            || compareId(left.serial, right.serial)
            || compareText(left.label, right.label);
    });

    var playbackStreams = nodes.filter(function (node) {
        return isPlaybackStream(node, playbackType);
    }).map(function (node) {
        var presentation = resolvePresentation ? resolvePresentation(node.ref || node) : null;
        var memberships = channelIdsForStream(node, channelNodes, links);
        var identity = presentation && text(presentation.canonicalId)
            ? text(presentation.canonicalId)
            : persistentIdentity(node);
        return {
            node: node.ref || null,
            id: node.id,
            serial: serial(node),
            persistentKey: persistentIdentity(node),
            canonicalId: identity,
            displayName: streamLabel(node, presentation),
            childLabel: childLabel(node),
            iconPath: presentation && presentation.iconPath ? presentation.iconPath : "",
            memberships: memberships,
            channelId: memberships.length === 1 ? memberships[0] : null,
            routingState: memberships.length === 0 ? "unrouted" :
                (memberships.length > 1 ? "ambiguous" : "routed")
        };
    }).sort(function (left, right) {
        return compareText(left.persistentKey, right.persistentKey)
            || compareId(left.serial, right.serial)
            || compareId(left.id, right.id);
    });

    var channels = channelNodes.map(function (channelNodeModel) {
        var definition = channelNodeModel.definition;
        var bridgePeer = linkedPeer(channelNodeModel.bridge, links, nodes);
        var peerNode = bridgePeer.node;
        var physical = peerNode
            ? isPhysicalSink(peerNode, audioSinkType, definitions, nodes)
            : false;
        var cycleSafe = physical && channelNodeModel.bridge
            ? !wouldCreateCycle(channelNodeModel.bridge, peerNode, graph)
            : false;
        var output = outputRecord(peerNode);
        if (output) {
            output.isPhysical = physical;
            output.isCycleSafe = cycleSafe;
        }
        var streams = playbackStreams.filter(function (stream) {
            return stream.channelId === definition.id;
        });
        var sink = channelNodeModel.sink;
        var bridge = channelNodeModel.bridge;

        return {
            id: definition.id,
            label: definition.label,
            sinkName: definition.sinkName,
            bridgeName: definition.bridgeName,
            isDefault: definition.isDefault === true,
            isObservedDefault: sink ? sameId(sink.id, defaultSinkId) : false,
            sink: sink ? sink.ref || null : null,
            sinkId: sink ? sink.id : null,
            sinkSerial: sink ? serial(sink) : null,
            bridge: bridge ? bridge.ref || null : null,
            bridgeId: bridge ? bridge.id : null,
            bridgeSerial: bridge ? serial(bridge) : null,
            volume: bridge && bridge.audio ? bridge.audio.volume : null,
            muted: bridge && bridge.audio ? bridge.audio.muted : false,
            output: output,
            status: channelStatus(channelNodeModel, bridgePeer, output, graphReady),
            groups: groupStreams(streams)
        };
    });

    var observedDefault = null;
    channels.forEach(function (channel) {
        if (channel.isObservedDefault) {
            observedDefault = channel.id;
        }
    });

    return {
        channels: channels,
        physicalOutputs: outputs,
        unroutedGroups: groupStreams(playbackStreams.filter(function (stream) {
            return stream.channelId === null;
        })),
        playbackStreams: playbackStreams,
        observedDefaultChannelId: observedDefault,
        defaultWarning: observedDefault !== definitions.filter(function (definition) {
            return definition.isDefault === true;
        }).map(function (definition) {
            return definition.id;
        })[0]
    };
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        buildSnapshot: buildSnapshot,
        canonicalGlobalId: canonicalGlobalId,
        channelIdsForStream: channelIdsForStream,
        groupStreams: groupStreams,
        hasRealApplicationIdentity: hasRealApplicationIdentity,
        isPhysicalSink: isPhysicalSink,
        isSelectableOutput: isSelectableOutput,
        outputAvailable: outputAvailable,
        outputRecord: outputRecord,
        isPlaybackStream: isPlaybackStream,
        pathExists: pathExists,
        persistentIdentity: persistentIdentity,
        snapshotSignature: snapshotSignature,
        stableNameIsUnique: stableNameIsUnique,
        wouldCreateCycle: wouldCreateCycle
    };
}
