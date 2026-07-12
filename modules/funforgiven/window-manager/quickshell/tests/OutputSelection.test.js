const assert = require("node:assert/strict");
const test = require("node:test");

const OutputSelection = require("../mixer/OutputSelection.js");

function output(id, serial, available = true) {
    return { id, serial, available, label: `Output ${id}` };
}

test("preserves a highlighted output across fresh identities and reordering", () => {
    const firstGraph = [output(10, 100), output(20, 200), output(30, 300)];
    const rememberedKey = OutputSelection.outputKey(firstGraph[1]);
    const refreshedGraph = [output(30, 300), output(10, 100), output(20, 200)];

    assert.deepEqual(
        OutputSelection.reconcileSelection(refreshedGraph, rememberedKey, refreshedGraph[0]),
        { index: 2, key: rememberedKey, rehomed: false }
    );
});

test("retains an existing highlighted output when its availability changes", () => {
    const rememberedKey = OutputSelection.outputKey(output(20, 200));
    const refreshedGraph = [output(10, 100), output(20, 200, false)];

    assert.deepEqual(
        OutputSelection.reconcileSelection(refreshedGraph, rememberedKey, refreshedGraph[0]),
        { index: 1, key: rememberedKey, rehomed: false }
    );
});

test("re-homes only after the highlighted candidate disappears", () => {
    const rememberedKey = OutputSelection.outputKey(output(20, 200));
    const current = output(30, 300);
    const refreshedGraph = [output(10, 100), current];

    assert.deepEqual(
        OutputSelection.reconcileSelection(refreshedGraph, rememberedKey, current),
        { index: 1, key: OutputSelection.outputKey(current), rehomed: true }
    );
});

test("uses the first available output, then the first row, as explicit fallbacks", () => {
    const availableFallback = [output(10, 100, false), output(20, 200)];
    const unavailableFallback = [output(30, 300, false), output(40, 400, false)];

    assert.equal(OutputSelection.initialSelection(availableFallback, null).index, 1);
    assert.equal(OutputSelection.initialSelection(unavailableFallback, null).index, 0);
    assert.deepEqual(OutputSelection.initialSelection([], null), { index: -1, key: "", rehomed: false });
});

test("requires both id and serial for stable identity", () => {
    assert.equal(OutputSelection.outputKey(null), "");
    assert.equal(OutputSelection.outputKey({ id: 10 }), "");
    assert.notEqual(OutputSelection.outputKey(output(10, 100)), OutputSelection.outputKey(output(10, 101)));
});
