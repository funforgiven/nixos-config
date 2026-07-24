const assert = require("node:assert/strict");
const test = require("node:test");

const SessionCommand = require("../services/SessionCommand.js");

const actionUnits = {
    logout: "funforgiven-session-logout.service",
    reboot: "funforgiven-session-reboot.service",
    poweroff: "funforgiven-session-poweroff.service"
};

test("session actions start only the supervised user units", () => {
    const systemctl = "/nix/store/systemd/bin/systemctl";

    assert.deepEqual(SessionCommand.sessionAction(systemctl, actionUnits, "logout"), [
        systemctl,
        "--user",
        "start",
        "funforgiven-session-logout.service"
    ]);
    assert.deepEqual(SessionCommand.sessionAction(systemctl, actionUnits, "reboot"), [
        systemctl,
        "--user",
        "start",
        "funforgiven-session-reboot.service"
    ]);
    assert.deepEqual(SessionCommand.sessionAction(systemctl, actionUnits, "poweroff"), [
        systemctl,
        "--user",
        "start",
        "funforgiven-session-poweroff.service"
    ]);
});

test("session actions reject empty executables, arbitrary verbs, and arbitrary units", () => {
    assert.throws(() => SessionCommand.sessionAction("", actionUnits, "reboot"), /executable is empty/);
    assert.throws(() => SessionCommand.sessionAction("systemctl", actionUnits, "reboot"), /must be absolute/);
    assert.throws(() => SessionCommand.sessionAction("/bin/systemctl", actionUnits, "suspend"), /unsupported system action/);
    assert.throws(() => SessionCommand.sessionAction("/bin/systemctl", actionUnits, "--force"), /unsupported system action/);
    assert.throws(
        () => SessionCommand.sessionAction("/bin/systemctl", { poweroff: "poweroff.target" }, "poweroff"),
        /invalid session action unit/
    );
    assert.throws(
        () => SessionCommand.sessionAction(
            "/bin/systemctl",
            {
                logout: actionUnits.logout,
                reboot: actionUnits.poweroff,
                poweroff: actionUnits.reboot
            },
            "reboot"
        ),
        /invalid session action unit/
    );
});
