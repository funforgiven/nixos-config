const assert = require("node:assert/strict");
const test = require("node:test");

const AppIdentity = require("../services/AppIdentity.js");
const NiriProtocol = require("../services/NiriProtocol.js");

test("niri action builders match the pinned externally tagged IPC schema", () => {
    assert.deepEqual(NiriProtocol.quit(false), {
        Action: {
            Quit: {
                skip_confirmation: false
            }
        }
    });
    assert.deepEqual(NiriProtocol.focusWorkspace(42), {
        Action: {
            FocusWorkspace: {
                reference: { Id: 42 }
            }
        }
    });
    assert.deepEqual(NiriProtocol.focusWindow(7), {
        Action: {
            FocusWindow: { id: 7 }
        }
    });
    assert.deepEqual(NiriProtocol.focusMonitor("DP-1"), {
        Action: {
            FocusMonitor: { output: "DP-1" }
        }
    });
});

test("niri builders reject lossy IDs and invalid monitor names", () => {
    assert.equal(NiriProtocol.quit("false"), null);
    assert.equal(NiriProtocol.focusWorkspace(-1), null);
    assert.equal(NiriProtocol.focusWindow(1.5), null);
    assert.equal(NiriProtocol.focusWindow(9007199254740992), null);
    assert.equal(NiriProtocol.focusMonitor(""), null);
    assert.equal(NiriProtocol.focusMonitor("   "), null);
    assert.equal(NiriProtocol.focusMonitor(null), null);
});

test("niri reply parsing consumes success, compositor error, and unknown replies", () => {
    assert.deepEqual(NiriProtocol.replyResult({ Ok: "Handled" }), {
        ok: true,
        error: ""
    });
    assert.deepEqual(NiriProtocol.replyResult({ Err: "no such window" }), {
        ok: false,
        error: "no such window"
    });
    assert.equal(NiriProtocol.replyResult({ Future: {} }).ok, false);
});

test("application hints preserve primary ID and documented audio fallback order", () => {
    assert.deepEqual(AppIdentity.candidates({
        appId: "Firefox",
        applicationId: "firefox",
        processBinary: "firefox-bin",
        applicationName: "Firefox Audio"
    }), ["Firefox", "Firefox Audio", "firefox-bin"]);
    assert.deepEqual(AppIdentity.primaryCandidates({
        applicationId: "org.example.App",
        applicationName: "Example",
        processBinary: "example-bin"
    }), ["org.example.App"]);
    assert.deepEqual(AppIdentity.fallbackCandidates({
        applicationName: "Example",
        processBinary: "example-bin"
    }), ["Example", "example-bin"]);
});

test("declarative aliases prefer exact keys before case-insensitive keys", () => {
    const aliases = {
        DISCORD: "exact.desktop",
        discord: "folded.desktop"
    };

    assert.deepEqual(AppIdentity.aliasFor(["DISCORD"], aliases), {
        source: "DISCORD",
        target: "exact.desktop"
    });
    assert.deepEqual(AppIdentity.aliasFor(["Discord"], {
        discord: "discord.desktop"
    }), {
        source: "Discord",
        target: "discord.desktop"
    });
});

test("generic application identity has a deterministic fallback", () => {
    assert.equal(AppIdentity.fallbackId(["Com.Example.App"]), "com.example.app");
    assert.equal(AppIdentity.fallbackId([]), "unknown-application");
});

test("identityless Niri windows keep stable per-window canonical IDs", () => {
    const unresolved = title => ({
        canonicalId: title.toLowerCase(),
        desktopEntry: null
    });

    assert.equal(AppIdentity.windowCanonicalId(unresolved("First title"), "", 42), "niri-window:42");
    assert.equal(AppIdentity.windowCanonicalId(unresolved("Renamed title"), "", 42), "niri-window:42");
    assert.notEqual(
        AppIdentity.windowCanonicalId(unresolved("Shared title"), "", 42),
        AppIdentity.windowCanonicalId(unresolved("Shared title"), "", 43)
    );
    assert.equal(
        AppIdentity.windowCanonicalId(unresolved("Title"), "org.example.App", 42),
        "title"
    );
    assert.equal(
        AppIdentity.windowCanonicalId({
            canonicalId: "org.example.App",
            desktopEntry: { id: "org.example.App" }
        }, "", 42),
        "org.example.App"
    );
});

test("desktop-entry fallback matching covers application names and process binaries", () => {
    const entry = {
        name: "Example Player",
        genericName: "Music Player",
        command: ["/nix/store/example/bin/example-player", "--open"]
    };

    assert.equal(AppIdentity.entryMatchesName(entry, "example player"), true);
    assert.equal(AppIdentity.entryMatchesName(entry, "MUSIC PLAYER"), true);
    assert.equal(AppIdentity.entryMatchesExecutable(entry, "example-player"), true);
    assert.equal(AppIdentity.entryMatchesExecutable(entry, "/nix/store/example/bin/example-player"), true);
    assert.equal(AppIdentity.entryMatchesExecutable(entry, "other-player"), false);
});

test("absolute and URL icon sources bypass theme-name resolution", () => {
    assert.equal(AppIdentity.directIconSource("/nix/store/example/icon.svg"), "/nix/store/example/icon.svg");
    assert.equal(AppIdentity.directIconSource("file:///tmp/icon.png"), "file:///tmp/icon.png");
    assert.equal(AppIdentity.directIconSource("image://icon/firefox"), "image://icon/firefox");
    assert.equal(AppIdentity.directIconSource("firefox"), "");
});
