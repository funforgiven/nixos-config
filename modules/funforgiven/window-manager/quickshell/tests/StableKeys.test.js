const assert = require("node:assert/strict");
const test = require("node:test");

const StableKeys = require("../components/StableKeys.js");

const keyFor = item => item.key;

test("retains the exact key array when only authoritative values change", () => {
    const previous = ["system", "game"];
    const reconciled = StableKeys.reconcile(previous, [
        { key: "system", volume: 0.42 },
        { key: "game", volume: 0.75 }
    ], keyFor);

    assert.strictEqual(reconciled, previous);
});

test("publishes a new deterministic sequence for membership or order changes", () => {
    const previous = ["system", "game"];

    assert.deepEqual(StableKeys.reconcile(previous, [
        { key: "game" },
        { key: "system" }
    ], keyFor), ["game", "system"]);
    assert.deepEqual(StableKeys.reconcile(previous, [
        { key: "system" },
        { key: "game" },
        { key: "voice" }
    ], keyFor), ["system", "game", "voice"]);
});

test("find resolves fresh values by stable key", () => {
    const values = [
        { key: "stream:1:10", label: "First" },
        { key: "stream:2:20", label: "Second" }
    ];

    assert.equal(StableKeys.find(values, "stream:2:20", keyFor).label, "Second");
    assert.equal(StableKeys.find(values, "missing", keyFor), null);
});

test("empty and duplicate keys fail loudly", () => {
    assert.throws(() => StableKeys.project([{ key: "" }], keyFor), /key is empty/);
    assert.throws(() => StableKeys.project([{ key: "same" }, { key: "same" }], keyFor), /duplicate stable model key/);
});
