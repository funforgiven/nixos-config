const assert = require("node:assert/strict");
const test = require("node:test");

const LaunchCommand = require("../services/LaunchCommand.js");

test("desktop entries launch through app2unit as one typed argv", () => {
    const command = LaunchCommand.app2unitService(
        "/nix/store/app2unit/bin/app2unit",
        "firefox",
        "10s"
    );

    assert.deepEqual(command, [
        "/nix/store/app2unit/bin/app2unit",
        "-t",
        "service",
        "-s",
        "app-graphical.slice",
        "-p",
        "TimeoutStopSec=10s",
        "-p",
        "KillMode=control-group",
        "-p",
        "KillSignal=SIGTERM",
        "-p",
        "SendSIGKILL=yes",
        "--",
        "firefox.desktop"
    ]);
    assert.equal(command.some(argument => argument.indexOf("JobTimeout") >= 0), false);
});

test("desktop-entry units require a bounded stop timeout", () => {
    assert.throws(
        () => LaunchCommand.app2unitService("/nix/store/app2unit/bin/app2unit", "firefox", ""),
        /positive whole number/
    );
    assert.throws(
        () => LaunchCommand.app2unitService("/nix/store/app2unit/bin/app2unit", "firefox", "forever"),
        /positive whole number/
    );
});

test("desktop entry IDs are normalized exactly once", () => {
    assert.equal(LaunchCommand.desktopEntryId("org.example.App.desktop"), "org.example.App.desktop");
    assert.equal(LaunchCommand.desktopEntryId(" org.example.App "), "org.example.App.desktop");
    assert.throws(() => LaunchCommand.desktopEntryId("  "), /desktop entry ID is empty/);
});
