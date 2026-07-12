const assert = require("node:assert/strict");
const test = require("node:test");

const DragModel = require("../mixer/DragModel.js");

function payload(sourceChannelId = "music") {
    return {
        kind: "funforgiven-audio-streams",
        canonicalId: "org.example.Player",
        sourceChannelId,
        selection: {
            kind: "group",
            persistentKey: "Output/Audio:application.id:org.example.Player"
        },
        streams: [
            {
                id: 42,
                serial: 1042,
                canonicalId: "org.example.Player",
                persistentKey: "org.example.Player"
            }
        ]
    };
}

test("normalizes only complete typed stream payloads", () => {
    assert.deepEqual(DragModel.normalizePayload(payload()), payload());
    assert.equal(DragModel.normalizePayload(null), null);
    assert.equal(DragModel.normalizePayload({ ...payload(), kind: "text/plain" }), null);
    assert.equal(DragModel.normalizePayload({ ...payload(), streams: [] }), null);
    assert.equal(DragModel.normalizePayload({ ...payload(), streams: [{ id: 42 }] }), null);
    assert.equal(DragModel.normalizePayload({ ...payload(), streams: [payload().streams[0], payload().streams[0]] }), null);
    assert.equal(DragModel.normalizePayload({ ...payload(), selection: null }), null);
});

test("derives group and individual payloads from the rendered stream records", () => {
    const group = {
        key: "Output/Audio:application.id:org.example.Player",
        canonicalId: "org.example.Player",
        streams: payload().streams
    };
    assert.deepEqual(DragModel.groupPayload(group, "music"), payload("music"));

    const single = DragModel.singleStreamPayload(payload().streams[0], "voice");
    assert.equal(single.selection.kind, "stream");
    assert.deepEqual(single.selection.stream, payload().streams[0]);
    assert.equal(single.sourceChannelId, "voice");
});

test("rejects the authoritative source channel and unavailable targets", () => {
    assert.equal(DragModel.canDrop(payload("music"), "music", true), false);
    assert.equal(DragModel.canDrop(payload("music"), "game", false), false);
    assert.equal(DragModel.canDrop(payload("music"), "game", true), true);
    assert.equal(DragModel.canDrop(payload(""), "system", true), true);
});

test("keyboard routing finds the next available non-current channel", () => {
    const definitions = [
        { id: "system" },
        { id: "game" },
        { id: "voice" },
        { id: "music" }
    ];
    const available = id => id !== "voice";

    assert.equal(DragModel.adjacentChannelId(definitions, "system", 1, available), "game");
    assert.equal(DragModel.adjacentChannelId(definitions, "game", 1, available), "music");
    assert.equal(DragModel.adjacentChannelId(definitions, "system", -1, available), "music");
    assert.equal(DragModel.adjacentChannelId(definitions, "", 1, available), "system");
    assert.equal(DragModel.adjacentChannelId(definitions, "", -1, available), "music");
    assert.equal(DragModel.adjacentChannelId(definitions, "system", 1, () => false), "");
});
