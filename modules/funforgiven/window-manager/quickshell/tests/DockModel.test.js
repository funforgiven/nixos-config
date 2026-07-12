const assert = require("node:assert/strict");
const test = require("node:test");

const DockModel = require("../dock/DockModel.js");
const StableKeys = require("../components/StableKeys.js");

const keyFor = group => group.key;

test("dock order depends only on stable canonical group keys", () => {
    const first = DockModel.orderUnpinned([
        { key: "zeta", displayName: "A label" },
        { key: "alpha", displayName: "Z label" }
    ]);
    const renamedAndReversed = DockModel.orderUnpinned([
        { key: "alpha", displayName: "AAA renamed" },
        { key: "zeta", displayName: "ZZZ renamed" }
    ]);

    assert.deepEqual(first.map(keyFor), ["alpha", "zeta"]);
    assert.deepEqual(renamedAndReversed.map(keyFor), ["alpha", "zeta"]);
});

test("focus, urgency, title, and window updates retain dock model identity", () => {
    const previousKeys = ["firefox", "steam"];
    const liveUpdate = [
        { key: "firefox", focused: false, urgent: true, windows: [{ title: "Changed" }] },
        { key: "steam", focused: true, urgent: false, windows: [{ title: "Library" }] }
    ];

    assert.strictEqual(StableKeys.reconcile(previousKeys, liveUpdate, keyFor), previousKeys);
});
