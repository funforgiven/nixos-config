const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const NiriState = require("../services/NiriState.js");

const fixtureDirectory = path.join(__dirname, "fixtures");

function fixture(name) {
    return fs.readFileSync(path.join(fixtureDirectory, name), "utf8")
        .split("\n")
        .filter(line => line.trim() !== "")
        .map(line => JSON.parse(line));
}

function openedState(previous) {
    return NiriState.connectionOpened(previous || NiriState.createState());
}

function applyFixture(state, name) {
    return NiriState.reduceAll(state, fixture(name));
}

function byId(items, id) {
    return items.find(item => item.id === id);
}

test("fixtures cover every event variant owned by the shell reducer", () => {
    const required = [
        "WorkspacesChanged",
        "WorkspaceActivated",
        "WorkspaceActiveWindowChanged",
        "WorkspaceUrgencyChanged",
        "WindowsChanged",
        "WindowOpenedOrChanged",
        "WindowClosed",
        "WindowFocusChanged",
        "WindowFocusTimestampChanged",
        "WindowUrgencyChanged",
        "WindowLayoutsChanged",
        "ConfigLoaded"
    ];
    const fixtureNames = fs.readdirSync(fixtureDirectory)
        .filter(name => name.endsWith(".jsonl"));
    const variants = new Set(
        fixtureNames.flatMap(name => fixture(name).flatMap(Object.keys))
    );

    assert.deepEqual(required.filter(variant => !variants.has(variant)), []);
});

test("initial stream uses pinned niri shapes and publishes deterministic clones", () => {
    let state = openedState();
    state = applyFixture(state, "initial-state.jsonl");

    const first = NiriState.publish(state);
    const second = NiriState.publish(state);

    assert.equal(first.connected, true);
    assert.equal(first.stale, false);
    assert.equal(first.configLoaded, true);
    assert.equal(first.configFailed, false);
    assert.deepEqual(first.workspaces.map(workspace => workspace.id), [33, 11, 22]);
    assert.deepEqual(first.windows.map(window => window.id), [102, 201, 301]);
    assert.equal(byId(first.windows, 301).workspace_id, null);
    assert.notStrictEqual(first.workspaces, second.workspaces);
    assert.notStrictEqual(first.workspaces[0], second.workspaces[0]);
    assert.notStrictEqual(first.windows, second.windows);
    assert.notStrictEqual(first.windows[0], second.windows[0]);
    assert.notStrictEqual(first.windows[0].layout, second.windows[0].layout);

    first.workspaces[0].name = "mutated publication";
    first.windows[0].layout.tile_size[0] = -1;
    const third = NiriState.publish(state);
    assert.equal(third.workspaces[0].name, "games");
    assert.deepEqual(third.windows[0].layout.tile_size, [1920, 1080]);
});

test("full workspace snapshots represent output hotplug and replace old state", () => {
    const events = fixture("hotplugged-outputs.jsonl");
    let state = openedState();

    state = NiriState.reduce(state, events[0]);
    assert.equal(byId(NiriState.publish(state).workspaces, 71).output, null);

    state = NiriState.reduce(state, events[1]);
    const workspaces = NiriState.publish(state).workspaces;
    assert.deepEqual(workspaces.map(workspace => workspace.id), [71, 73, 72]);
    assert.equal(byId(workspaces, 71).output, "DP-3");
    assert.equal(byId(workspaces, 72).idx, 2);
});

test("workspace deltas preserve niri active/focused semantics and dangling IDs", () => {
    const events = fixture("moving-workspaces.jsonl");
    let state = openedState();
    state = NiriState.reduceAll(state, events.slice(0, 5));

    const beforeMissingIds = state;
    state = NiriState.reduceAll(state, events.slice(5));
    assert.strictEqual(state, beforeMissingIds);

    const workspaces = NiriState.publish(state).workspaces;
    assert.deepEqual(workspaces.map(workspace => workspace.id), [1, 2, 3]);
    assert.equal(byId(workspaces, 1).is_active, true);
    assert.equal(byId(workspaces, 1).is_focused, false);
    assert.equal(byId(workspaces, 2).is_active, false);
    assert.equal(byId(workspaces, 3).is_active, true);
    assert.equal(byId(workspaces, 3).is_focused, true);
    assert.equal(byId(workspaces, 3).is_urgent, true);
    assert.equal(byId(workspaces, 3).active_window_id, 909);
});

test("window churn tolerates missing IDs and keeps full pinned layout values", () => {
    const events = fixture("rapid-windows.jsonl");
    let state = openedState();

    state = NiriState.reduceAll(state, events.slice(0, 5));
    assert.equal(NiriState.publish(state).windows[0].workspace_id, null);

    state = NiriState.reduceAll(state, events.slice(5));
    const windows = NiriState.publish(state).windows;

    assert.deepEqual(windows.map(window => window.id), [501]);
    assert.equal(windows[0].title, "Ready");
    assert.equal(windows[0].workspace_id, 44);
    assert.equal(windows[0].is_focused, true);
    assert.equal(windows[0].is_urgent, true);
    assert.deepEqual(windows[0].focus_timestamp, { secs: 200, nanos: 300 });
    assert.deepEqual(windows[0].layout, {
        pos_in_scrolling_layout: [1, 2],
        tile_size: [960, 540],
        window_size: [940, 500],
        tile_pos_in_workspace_view: [0, 540],
        window_offset_in_tile: [10, 20]
    });
});

test("focused upserts clear other focus and nullable focus clears every window", () => {
    const events = fixture("rapid-windows.jsonl");
    let state = openedState();

    state = NiriState.reduceAll(state, events.slice(0, 7));
    let windows = NiriState.publish(state).windows;
    assert.equal(byId(windows, 501).is_focused, false);
    assert.equal(byId(windows, 502).is_focused, true);

    state = NiriState.reduce(state, { WindowFocusChanged: { id: null } });
    windows = NiriState.publish(state).windows;
    assert.equal(windows.every(window => window.is_focused === false), true);
});

test("unknown variants, handshake replies, and unhandled niri events are ignored", () => {
    let state = applyFixture(openedState(), "initial-state.jsonl");

    for (const event of fixture("unknown-events.jsonl")) {
        const previous = state;
        state = NiriState.reduce(state, event);
        assert.strictEqual(state, previous);
    }
});

test("new payload and model fields survive without affecting known reduction", () => {
    const source = {
        WindowOpenedOrChanged: {
            future_payload_field: "ignored",
            window: {
                id: 610,
                title: "Future",
                app_id: "future",
                pid: null,
                workspace_id: null,
                is_focused: false,
                is_floating: false,
                is_urgent: false,
                layout: {
                    pos_in_scrolling_layout: null,
                    tile_size: [1, 1],
                    window_size: [1, 1],
                    tile_pos_in_workspace_view: null,
                    window_offset_in_tile: [0, 0]
                },
                focus_timestamp: null,
                field_added_by_niri: { nested: [1, 2, 3] }
            }
        }
    };
    const state = NiriState.reduce(openedState(), source);

    source.WindowOpenedOrChanged.window.field_added_by_niri.nested[0] = 99;
    assert.deepEqual(NiriState.publish(state).windows[0].field_added_by_niri, {
        nested: [1, 2, 3]
    });
});

test("event state stays stale until both initial workspace and window snapshots arrive", () => {
    let state = openedState();
    let view = NiriState.publish(state);

    assert.equal(view.connected, true);
    assert.equal(view.stale, true);

    state = NiriState.reduce(state, {
        WorkspacesChanged: {
            workspaces: []
        }
    });
    assert.equal(NiriState.publish(state).stale, true);

    state = NiriState.reduce(state, {
        WindowsChanged: {
            windows: []
        }
    });
    view = NiriState.publish(state);
    assert.equal(view.connected, true);
    assert.equal(view.stale, false);
});

test("disconnect marks a model stale and reconnect clears it before new snapshots", () => {
    let state = openedState();
    state = applyFixture(state, "reconnect-old.jsonl");

    state = NiriState.connectionClosed(state, new Error("socket disappeared"));
    let view = NiriState.publish(state);
    assert.equal(view.connected, false);
    assert.equal(view.stale, true);
    assert.equal(view.error, "socket disappeared");
    assert.deepEqual(view.workspaces.map(workspace => workspace.id), [801]);

    state = NiriState.connectionOpened(state);
    view = NiriState.publish(state);
    assert.equal(view.generation, 2);
    assert.equal(view.connected, true);
    assert.equal(view.stale, true);
    assert.equal(view.error, null);
    assert.deepEqual(view.workspaces, []);
    assert.deepEqual(view.windows, []);
    assert.equal(view.configLoaded, false);
    assert.equal(view.configFailed, false);

    state = applyFixture(state, "reconnect-new.jsonl");
    view = NiriState.publish(state);
    assert.deepEqual(view.workspaces.map(workspace => workspace.id), [901]);
    assert.deepEqual(view.windows, []);
    assert.equal(view.stale, false);
    assert.equal(view.configLoaded, true);
    assert.equal(view.configFailed, false);
});

test("connection errors expose an actionable stale state", () => {
    const state = NiriState.connectionError(openedState(), {
        message: "invalid JSON from event stream"
    });
    const view = NiriState.publish(state);

    assert.equal(view.connected, false);
    assert.equal(view.stale, true);
    assert.equal(view.error, "invalid JSON from event stream");
});
