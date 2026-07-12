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
    if (!value || value.id === null || value.id === undefined
            || value.serial === null || value.serial === undefined)
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

function streamKey(value) {
    var reference = streamReference(value);
    return reference === null ? "" : text(reference.id) + ":" + text(reference.serial);
}

function uniqueReferences(input) {
    var seen = Object.create(null);
    var result = [];
    values(input).forEach(function (value) {
        var reference = streamReference(value);
        var key = streamKey(reference);
        if (reference !== null && !seen[key]) {
            seen[key] = true;
            result.push(reference);
        }
    });
    return result;
}

function groupSelection(persistentKey) {
    persistentKey = text(persistentKey);
    return persistentKey.length === 0 ? null : {
        kind: "group",
        persistentKey: persistentKey
    };
}

function streamSelection(value) {
    var reference = streamReference(value);
    return reference === null ? null : {
        kind: "stream",
        stream: reference
    };
}

function referencesSelection(input) {
    var streams = uniqueReferences(input);
    return streams.length === 0 ? null : {
        kind: "references",
        streams: streams
    };
}

function normalizeSelection(value) {
    if (!value)
        return null;
    if (value.kind === "group")
        return groupSelection(value.persistentKey);
    if (value.kind === "stream")
        return streamSelection(value.stream);
    if (value.kind === "references")
        return referencesSelection(value.streams);
    return null;
}

function resolveSelection(value, liveStreams) {
    var selection = normalizeSelection(value);
    if (selection === null)
        return [];

    var live = uniqueReferences(liveStreams);
    if (selection.kind === "group") {
        return live.filter(function (stream) {
            return stream.persistentKey === selection.persistentKey;
        });
    }

    var selected = selection.kind === "stream" ? [selection.stream] : selection.streams;
    var selectedKeys = Object.create(null);
    selected.forEach(function (stream) {
        selectedKeys[streamKey(stream)] = true;
    });
    return live.filter(function (stream) {
        return selectedKeys[streamKey(stream)] === true;
    });
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        groupSelection: groupSelection,
        normalizeSelection: normalizeSelection,
        referencesSelection: referencesSelection,
        resolveSelection: resolveSelection,
        streamKey: streamKey,
        streamReference: streamReference,
        streamSelection: streamSelection,
        uniqueReferences: uniqueReferences,
        values: values
    };
}
