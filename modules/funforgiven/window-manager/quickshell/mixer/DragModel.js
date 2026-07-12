function text(value) {
    return value === null || value === undefined ? "" : String(value).trim();
}

function values(value) {
    if (Array.isArray(value))
        return value;
    if (!value || typeof value.length !== "number" || value.length < 0)
        return [];
    var result = [];
    for (var index = 0; index < value.length; index += 1)
        result.push(value[index]);
    return result;
}

function streamReference(value) {
    if (!value || value.id === null || value.id === undefined || value.serial === null || value.serial === undefined)
        return null;
    var id = text(value.id);
    var serial = text(value.serial);
    if (id.length === 0 || serial.length === 0)
        return null;
    return {
        id: value.id,
        serial: value.serial,
        canonicalId: text(value.canonicalId),
        persistentKey: text(value.persistentKey)
    };
}

function normalizePayload(value) {
    if (!value || value.kind !== "funforgiven-audio-streams")
        return null;
    var seen = Object.create(null);
    var duplicate = false;
    var inputStreams = values(value.streams);
    var streams = inputStreams.map(streamReference).filter(function (stream) {
        if (stream === null)
            return false;
        var key = text(stream.id) + ":" + text(stream.serial);
        if (seen[key]) {
            duplicate = true;
            return false;
        }
        seen[key] = true;
        return true;
    });
    if (duplicate || streams.length === 0 || streams.length !== inputStreams.length)
        return null;

    var selection = value.selection;
    if (!selection || (selection.kind !== "group" && selection.kind !== "stream"))
        return null;
    if (selection.kind === "group") {
        var persistentKey = text(selection.persistentKey);
        if (persistentKey.length === 0)
            return null;
        selection = {
            kind: "group",
            persistentKey: persistentKey
        };
    } else {
        var selectedStream = streamReference(selection.stream);
        if (selectedStream === null || streams.length !== 1
                || text(selectedStream.id) !== text(streams[0].id)
                || text(selectedStream.serial) !== text(streams[0].serial))
            return null;
        selection = {
            kind: "stream",
            stream: selectedStream
        };
    }

    return {
        kind: "funforgiven-audio-streams",
        canonicalId: text(value.canonicalId),
        sourceChannelId: text(value.sourceChannelId),
        selection: selection,
        streams: streams
    };
}

function groupPayload(group, sourceChannelId) {
    if (!group)
        return null;
    return normalizePayload({
        kind: "funforgiven-audio-streams",
        canonicalId: group.canonicalId,
        sourceChannelId: sourceChannelId,
        selection: {
            kind: "group",
            persistentKey: group.key
        },
        streams: group.streams
    });
}

function singleStreamPayload(stream, sourceChannelId) {
    if (!stream)
        return null;
    return normalizePayload({
        kind: "funforgiven-audio-streams",
        canonicalId: stream.canonicalId,
        sourceChannelId: sourceChannelId,
        selection: {
            kind: "stream",
            stream: stream
        },
        streams: [stream]
    });
}

function canDrop(value, targetChannelId, targetAvailable) {
    var payload = normalizePayload(value);
    return payload !== null
        && targetAvailable === true
        && text(targetChannelId).length > 0
        && payload.sourceChannelId !== text(targetChannelId);
}

function adjacentChannelId(definitions, currentChannelId, direction, isAvailable) {
    definitions = Array.isArray(definitions) ? definitions : [];
    if (definitions.length === 0 || typeof isAvailable !== "function")
        return "";

    var current = text(currentChannelId);
    var currentIndex = definitions.findIndex(function (definition) {
        return definition && text(definition.id) === current;
    });
    var step = Number(direction) < 0 ? -1 : 1;
    if (currentIndex < 0)
        currentIndex = step > 0 ? -1 : 0;

    for (var offset = 1; offset <= definitions.length; offset += 1) {
        var index = (currentIndex + step * offset + definitions.length) % definitions.length;
        var definition = definitions[index];
        var candidate = definition ? text(definition.id) : "";
        if (candidate.length > 0 && candidate !== current && isAvailable(candidate))
            return candidate;
    }
    return "";
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        adjacentChannelId: adjacentChannelId,
        canDrop: canDrop,
        groupPayload: groupPayload,
        normalizePayload: normalizePayload,
        singleStreamPayload: singleStreamPayload,
        streamReference: streamReference
    };
}
