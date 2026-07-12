const assert = require("node:assert/strict");
const test = require("node:test");

const PolkitPlacement = require("../polkit/PolkitPlacement.js");

const screens = [
    { name: "DP-1" },
    { name: "HDMI-A-2" },
    { name: "DP-3" }
];

test("polkit prompt follows the one focused Niri workspace output", () => {
    const workspaces = [
        { id: 1, output: "DP-1", is_focused: false },
        { id: 2, output: "HDMI-A-2", is_focused: true },
        { id: 3, output: "DP-3", is_focused: false }
    ];

    assert.equal(PolkitPlacement.focusedScreen(workspaces, screens), screens[1]);
});

test("a disconnected focused output falls back to a connected screen", () => {
    const workspaces = [
        { id: 2, output: "DP-9", is_focused: true }
    ];

    assert.equal(PolkitPlacement.focusedScreen(workspaces, screens), screens[0]);
});

test("inconsistent multiple-focus state fails visibly on the first screen", () => {
    const workspaces = [
        { id: 1, output: "DP-1", is_focused: true },
        { id: 2, output: "HDMI-A-2", is_focused: true }
    ];

    assert.equal(PolkitPlacement.focusedScreen(workspaces, screens), screens[0]);
});

test("screen lookup is exact and empty screen state has no target", () => {
    assert.equal(PolkitPlacement.screenForName(screens, "DP-1"), screens[0]);
    assert.equal(PolkitPlacement.screenForName(screens, "dp-1"), null);
    assert.equal(PolkitPlacement.focusedScreen([], []), null);
});
