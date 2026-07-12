const assert = require("node:assert/strict");
const test = require("node:test");

const SessionCommand = require("../services/SessionCommand.js");

test("system power actions use one inhibitor-aware typed argv", () => {
    const systemctl = "/nix/store/systemd/bin/systemctl";

    assert.deepEqual(SessionCommand.systemctl(systemctl, "reboot"), [
        systemctl,
        "--check-inhibitors=yes",
        "reboot"
    ]);
    assert.deepEqual(SessionCommand.systemctl(systemctl, "poweroff"), [
        systemctl,
        "--check-inhibitors=yes",
        "poweroff"
    ]);
});

test("system power actions reject empty executables and arbitrary verbs", () => {
    assert.throws(() => SessionCommand.systemctl("", "reboot"), /executable is empty/);
    assert.throws(() => SessionCommand.systemctl("systemctl", "reboot"), /must be absolute/);
    assert.throws(() => SessionCommand.systemctl("/bin/systemctl", "suspend"), /unsupported system action/);
    assert.throws(() => SessionCommand.systemctl("/bin/systemctl", "--force"), /unsupported system action/);
    assert.throws(() => SessionCommand.systemctl("/bin/systemctl", "--check-inhibitors=no"), /unsupported system action/);
});
