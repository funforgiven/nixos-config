// Launcher interaction reference licenses are recorded in THIRD_PARTY_NOTICES.md.

const assert = require("node:assert/strict");
const test = require("node:test");

const LauncherModel = require("../launcher/LauncherModel.js");

const applications = [
    {
        id: "org.mozilla.firefox",
        name: "Firefox",
        genericName: "Web Browser",
        comment: "Browse the web",
        keywords: ["internet", "network"],
        iconPath: "firefox"
    },
    {
        id: "org.gnome.Nautilus",
        name: "Files",
        genericName: "File Manager",
        comment: "Access and organize files"
    },
    {
        id: "foot.desktop",
        name: "Foot",
        genericName: "Terminal"
    },
    {
        id: "visual-studio-code.desktop",
        name: "Visual Studio Code",
        genericName: "Code Editor"
    }
];

test("launcher search is deterministic and ranks exact, prefix, token, and subsequence matches", () => {
    assert.deepEqual(
        LauncherModel.filterApplications(applications, "").map(entry => entry.name),
        ["Files", "Firefox", "Foot", "Visual Studio Code"]
    );
    assert.equal(LauncherModel.filterApplications(applications, "fire")[0].name, "Firefox");
    assert.equal(LauncherModel.filterApplications(applications, "studio code")[0].name, "Visual Studio Code");
    assert.equal(LauncherModel.filterApplications(applications, "vsc")[0].name, "Visual Studio Code");
    assert.equal(LauncherModel.filterApplications(applications, "network")[0].name, "Firefox");
    assert.deepEqual(LauncherModel.filterApplications(applications, "no matching application"), []);
});

test("launcher search deduplicates desktop IDs without mutating its input", () => {
    const source = applications.concat({
        id: "foot.desktop",
        name: "Duplicate Foot"
    });
    const before = structuredClone(source);

    assert.equal(LauncherModel.filterApplications(source, "foot").length, 1);
    assert.deepEqual(source, before);
});

test("keyboard selection wraps and handles an empty model", () => {
    assert.equal(LauncherModel.moveSelection(-1, 1, 4), 0);
    assert.equal(LauncherModel.moveSelection(0, -1, 4), 3);
    assert.equal(LauncherModel.moveSelection(3, 1, 4), 0);
    assert.equal(LauncherModel.moveSelection(2, 8, 4), 2);
    assert.equal(LauncherModel.moveSelection(0, 1, 0), -1);
});

test("pointer selection requires deliberate movement", () => {
    assert.equal(LauncherModel.pointerMovedEnough({ x: 10, y: 10 }, { x: 13, y: 13 }, 5), false);
    assert.equal(LauncherModel.pointerMovedEnough({ x: 10, y: 10 }, { x: 14, y: 13 }, 5), true);
    assert.equal(LauncherModel.pointerMovedEnough(null, { x: 20, y: 20 }, 5), false);
});
