const assert = require("node:assert/strict");
const test = require("node:test");

const AudioRouting = require("../services/AudioRouting.js");

function stream(id, serial, persistentKey = "player") {
    return {
        id,
        serial,
        canonicalId: "org.example.Player",
        persistentKey
    };
}

test("group intent resolves against current graph members after delegate churn", () => {
    const stale = [stream(42, 1042)];
    const current = [stream(77, 2077), stream(78, 2078), stream(90, 2090, "other")];
    const selection = AudioRouting.groupSelection(stale[0].persistentKey);

    assert.deepEqual(
        AudioRouting.resolveSelection(selection, current).map(item => [item.id, item.serial]),
        [[77, 2077], [78, 2078]]
    );
});

test("individual intent never retargets a replacement stream with a reused id", () => {
    const selection = AudioRouting.streamSelection(stream(42, 1042));
    assert.deepEqual(AudioRouting.resolveSelection(selection, [stream(42, 2042)]), []);
    assert.deepEqual(AudioRouting.resolveSelection(selection, [stream(42, 1042)]).map(item => item.serial), [1042]);
});

test("normalizes QML-style array-like references and removes duplicates", () => {
    const first = stream(42, 1042);
    const arrayLike = { 0: first, 1: first, length: 2 };
    assert.deepEqual(AudioRouting.uniqueReferences(arrayLike), [first]);
    assert.equal(AudioRouting.referencesSelection([]), null);
});
