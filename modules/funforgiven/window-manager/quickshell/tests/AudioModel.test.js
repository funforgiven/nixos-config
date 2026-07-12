const assert = require("node:assert/strict");
const test = require("node:test");

const AudioModel = require("../mixer/AudioModel.js");

const AudioOutStream = 21;
const AudioSink = 17;

const definitions = [
    channel("system", "System", true),
    channel("game", "Game", false),
    channel("voice", "Voice Chat", false),
    channel("music", "Music", false)
];

function channel(id, label, isDefault) {
    return {
        id,
        label,
        sinkName: `funforgiven.audio.channel.${id}`,
        bridgeName: `funforgiven.audio.channel.${id}.output`,
        isDefault
    };
}

function markedNode(id, definition, kind) {
    const name = kind === "sink" ? definition.sinkName : definition.bridgeName;
    return {
        id,
        name,
        description: name,
        type: kind === "sink" ? AudioSink : AudioOutStream,
        ready: true,
        audio: kind === "bridge" ? { volume: 0.75, muted: false } : null,
        properties: {
            "object.serial": String(id + 1000),
            "funforgiven.audio.channel": definition.id,
            "funforgiven.audio.kind": kind,
            "node.virtual": true
        }
    };
}

function application(id, serial, applicationId, mediaName) {
    return {
        id,
        name: `stream.${id}`,
        description: mediaName,
        type: AudioOutStream,
        ready: true,
        properties: {
            "object.serial": String(serial),
            "media.class": "Stream/Output/Audio",
            "application.id": applicationId,
            "application.name": applicationId,
            "media.name": mediaName
        }
    };
}

function physical(id, name) {
    return {
        id,
        name,
        description: name,
        type: AudioSink,
        ready: true,
        routeAvailable: true,
        properties: {
            "object.serial": String(id + 2000),
            "device.id": "42",
            "media.class": "Audio/Sink"
        }
    };
}

function graphFixture() {
    const nodes = [];
    const links = [];
    definitions.forEach((definition, index) => {
        nodes.push(markedNode(10 + index, definition, "sink"));
        nodes.push(markedNode(20 + index, definition, "bridge"));
    });
    nodes.push(physical(50, "alsa_output.main"));
    nodes.push(application(70, 7000, "org.example.Player", "Music"));
    nodes.push(application(71, 7001, "org.example.Player", "Effects"));
    links.push({ sourceId: 70, targetId: 13, usable: true });
    links.push({ sourceId: 71, targetId: 13, usable: true });
    definitions.forEach((definition, index) => {
        links.push({ sourceId: 20 + index, targetId: 50, usable: true });
    });
    return { nodes, links };
}

test("strictly includes playback streams and excludes marked/internal lookalikes", () => {
    const valid = application(1, 100, "org.example.Valid", "Playback");
    const capture = { ...valid, id: 2, type: 9 };
    const bridge = {
        ...valid,
        id: 3,
        properties: { ...valid.properties, "funforgiven.audio.kind": "bridge" }
    };
    const identityless = {
        ...valid,
        id: 4,
        properties: { "object.serial": "104", "media.name": "Filter endpoint" }
    };
    const monitor = {
        ...valid,
        id: 5,
        name: "alsa_output.monitor"
    };

    assert.equal(AudioModel.isPlaybackStream(valid, AudioOutStream), true);
    assert.equal(AudioModel.isPlaybackStream(capture, AudioOutStream), false);
    assert.equal(AudioModel.isPlaybackStream(bridge, AudioOutStream), false);
    assert.equal(AudioModel.isPlaybackStream(identityless, AudioOutStream), false);
    assert.equal(AudioModel.isPlaybackStream(monitor, AudioOutStream), false);
});

test("recognizes a live Quickshell QFlags ALSA playback node via its stable stream flag", () => {
    const hayase = {
        id: 82,
        name: "alsa_playback.hayase",
        description: "ALSA Playback",
        type: { flags: ["Audio", "Stream", "Source"] },
        isStream: true,
        isSink: false,
        ready: true,
        properties: {
            "object.serial": 1025,
            "media.class": "Stream/Output/Audio",
            "application.name": "PipeWire ALSA [hayase]",
            "application.process.binary": "hayase",
            "client.name": "PipeWire ALSA [hayase]"
        }
    };

    assert.equal(AudioModel.isPlaybackStream(hayase, AudioOutStream), true);

    const fixture = graphFixture();
    fixture.nodes.push(hayase);
    fixture.links.push({ sourceId: 82, targetId: 10, usable: true });
    const snapshot = AudioModel.buildSnapshot(
        definitions,
        fixture.nodes,
        fixture.links,
        AudioOutStream,
        AudioSink,
        10,
        () => ({ canonicalId: "hayase", displayName: "Hayase", iconPath: "" })
    );

    assert.equal(snapshot.playbackStreams.some(stream => stream.id === 82 && stream.serial === 1025), true);
    assert.equal(snapshot.channels[0].groups.some(group => group.canonicalId === "hayase"), true);
});

test("membership comes only from live link endpoints in either orientation", () => {
    const fixture = graphFixture();
    const snapshot = AudioModel.buildSnapshot(
        definitions,
        fixture.nodes,
        fixture.links,
        AudioOutStream,
        AudioSink,
        10,
        () => ({ canonicalId: "player", displayName: "Player", iconPath: "icon" })
    );

    assert.deepEqual(snapshot.channels.map(item => item.id), ["system", "game", "voice", "music"]);
    assert.equal(snapshot.channels[3].groups.length, 1);
    assert.equal(snapshot.channels[3].groups[0].count, 2);
    assert.deepEqual(snapshot.channels[3].groups[0].streams.map(stream => stream.id), [70, 71]);
    assert.equal(snapshot.channels[0].output.isCycleSafe, true);
    assert.equal(snapshot.channels[0].status.state, "connected");
    assert.equal(snapshot.unroutedGroups.length, 0);
    assert.equal(snapshot.observedDefaultChannelId, "system");
    assert.equal(snapshot.defaultWarning, false);
});

test("ambiguous and absent links stay graph-authoritative and appear unrouted", () => {
    const fixture = graphFixture();
    fixture.links.push({ sourceId: 70, targetId: 10, usable: true });
    fixture.links = fixture.links.filter(link => link.sourceId !== 71 || link.targetId !== 13);

    const snapshot = AudioModel.buildSnapshot(
        definitions,
        fixture.nodes,
        fixture.links,
        AudioOutStream,
        AudioSink,
        50,
        () => ({ canonicalId: "player", displayName: "Player", iconPath: "" })
    );

    assert.equal(snapshot.unroutedGroups.length, 1);
    assert.equal(snapshot.unroutedGroups[0].count, 2);
    assert.deepEqual(
        snapshot.unroutedGroups[0].streams.map(stream => stream.routingState).sort(),
        ["ambiguous", "unrouted"]
    );
    assert.equal(snapshot.defaultWarning, true);
});

test("hardware candidates are device-backed and reject virtual/marked/filter nodes", () => {
    const valid = physical(1, "alsa_output.valid");
    const noDevice = { ...valid, id: 2, properties: { "object.serial": "2" } };
    const virtual = {
        ...valid,
        id: 3,
        properties: { ...valid.properties, "node.virtual": "true" }
    };
    const marked = {
        ...valid,
        id: 4,
        properties: { ...valid.properties, "funforgiven.audio.kind": "sink" }
    };
    const monitor = { ...valid, id: 5, name: "alsa_output.valid.monitor" };
    const fallback = {
        ...valid,
        id: 6,
        properties: { ...valid.properties, "wireplumber.is-fallback": true }
    };
    const filter = {
        ...valid,
        id: 7,
        properties: { ...valid.properties, "node.link-group": "filter-chain" }
    };
    const nullSink = {
        ...valid,
        id: 8,
        properties: { ...valid.properties, "factory.name": "support.null-audio-sink" }
    };
    const numericName = { ...valid, id: 9, name: "42" };
    const collidingPath = {
        ...valid,
        id: 10,
        name: "alsa_output.other",
        properties: { ...valid.properties, "object.path": valid.name }
    };

    assert.equal(AudioModel.isPhysicalSink(valid, AudioSink, definitions), true);
    assert.equal(AudioModel.isPhysicalSink(noDevice, AudioSink, definitions), false);
    assert.equal(AudioModel.isPhysicalSink(virtual, AudioSink, definitions), false);
    assert.equal(AudioModel.isPhysicalSink(marked, AudioSink, definitions), false);
    assert.equal(AudioModel.isPhysicalSink(monitor, AudioSink, definitions), false);
    assert.equal(AudioModel.isPhysicalSink(fallback, AudioSink, definitions), false);
    assert.equal(AudioModel.isPhysicalSink(filter, AudioSink, definitions), false);
    assert.equal(AudioModel.isPhysicalSink(nullSink, AudioSink, definitions), false);
    assert.equal(AudioModel.isPhysicalSink(numericName, AudioSink, definitions), false);
    assert.equal(
        AudioModel.isPhysicalSink(valid, AudioSink, definitions, [valid, collidingPath]),
        false
    );
});

test("cycle proof includes the loopback's implicit sink-to-bridge edge", () => {
    const graph = Object.create(null);
    graph["50"] = ["10"];
    graph["10"] = ["20"];

    assert.equal(AudioModel.pathExists(graph, 50, 20), true);
    assert.equal(AudioModel.wouldCreateCycle({ id: 20 }, { id: 50 }, graph), true);
    assert.equal(AudioModel.wouldCreateCycle({ id: 20 }, { id: 51 }, graph), false);
});

test("a currently connected physical target reports an existing feedback cycle", () => {
    const fixture = graphFixture();
    fixture.links.push({ sourceId: 50, targetId: 10, usable: true });

    const snapshot = AudioModel.buildSnapshot(
        definitions,
        fixture.nodes,
        fixture.links,
        AudioOutStream,
        AudioSink,
        10,
        () => null
    );

    assert.equal(snapshot.channels[0].output.isPhysical, true);
    assert.equal(snapshot.channels[0].output.isCycleSafe, false);
    assert.equal(snapshot.channels[0].status.state, "error");
    assert.match(snapshot.channels[0].status.message, /feedback cycle/);
});

test("a disabled connected output stays visible but is unavailable for status and actions", () => {
    const fixture = graphFixture();
    const output = fixture.nodes.find(node => node.id === 50);
    output.properties["node.disabled"] = true;

    const disabled = AudioModel.buildSnapshot(
        definitions,
        fixture.nodes,
        fixture.links,
        AudioOutStream,
        AudioSink,
        10,
        () => null,
        true
    );
    const candidate = disabled.physicalOutputs[0];
    const system = disabled.channels[0];

    assert.equal(candidate.available, false);
    assert.equal(system.output.available, false);
    assert.equal(system.status.state, "waiting");
    assert.match(system.status.message, /unavailable/);
    assert.equal(AudioModel.isSelectableOutput(candidate, candidate.id, candidate.serial, "system"), false);

    delete output.properties["node.disabled"];
    const enabled = AudioModel.buildSnapshot(
        definitions,
        fixture.nodes,
        fixture.links,
        AudioOutStream,
        AudioSink,
        10,
        () => null,
        true
    );

    assert.equal(enabled.physicalOutputs[0].available, true);
    assert.equal(enabled.channels[0].output.available, true);
    assert.equal(enabled.channels[0].status.state, "connected");
    assert.equal(
        AudioModel.isSelectableOutput(
            enabled.physicalOutputs[0],
            enabled.physicalOutputs[0].id,
            enabled.physicalOutputs[0].serial,
            "system"
        ),
        true
    );
});

test("a route-unavailable physical target stays visible but cannot be selected", () => {
    const fixture = graphFixture();
    fixture.nodes.find(node => node.id === 50).routeAvailable = false;

    const snapshot = AudioModel.buildSnapshot(
        definitions,
        fixture.nodes,
        fixture.links,
        AudioOutStream,
        AudioSink,
        10,
        () => null,
        true
    );
    const candidate = snapshot.physicalOutputs[0];
    const system = snapshot.channels[0];

    assert.equal(candidate.available, false);
    assert.equal(system.output.isPhysical, true);
    assert.equal(system.output.available, false);
    assert.equal(system.status.state, "waiting");
    assert.match(system.status.message, /unavailable/);
    assert.equal(
        AudioModel.isSelectableOutput(candidate, candidate.id, candidate.serial, "system"),
        false
    );
});

test("graph readiness distinguishes connection startup from missing topology", () => {
    const connecting = AudioModel.buildSnapshot(
        definitions,
        [],
        [],
        AudioOutStream,
        AudioSink,
        null,
        () => null,
        false
    );
    const missing = AudioModel.buildSnapshot(
        definitions,
        [],
        [],
        AudioOutStream,
        AudioSink,
        null,
        () => null,
        true
    );

    assert.equal(connecting.channels.every(channelModel => channelModel.status.state === "connecting"), true);
    assert.equal(missing.channels.every(channelModel => channelModel.status.state === "error"), true);
});

test("persistent grouping follows WirePlumber's exact case-sensitive key", () => {
    const first = application(1, 101, "org.example.App", "First role");
    const second = application(2, 102, "org.example.App", "Second role");
    second.properties["application.name"] = "Different display name";

    assert.equal(AudioModel.persistentIdentity(first), "Output/Audio:application.id:org.example.App");
    assert.equal(
        AudioModel.persistentIdentity(first),
        AudioModel.persistentIdentity(second)
    );

    const differentCase = application(3, 103, "ORG.EXAMPLE.PLAYER", "Third role");
    assert.notEqual(
        AudioModel.persistentIdentity(first),
        AudioModel.persistentIdentity(differentCase)
    );

    const spaced = application(4, 104, " org.example.App ", "Spaced identity");
    assert.equal(
        AudioModel.persistentIdentity(spaced),
        "Output/Audio:application.id: org.example.App "
    );
});

test("mutable presentation labels never reorder groups or their live children", () => {
    const streams = [
        {
            id: 90,
            serial: 9002,
            persistentKey: "Output/Audio:application.id:z.player",
            canonicalId: "z.player",
            displayName: "A label",
            childLabel: "A title"
        },
        {
            id: 91,
            serial: 9001,
            persistentKey: "Output/Audio:application.id:z.player",
            canonicalId: "z.player",
            displayName: "A label",
            childLabel: "Z title"
        },
        {
            id: 80,
            serial: 8001,
            persistentKey: "Output/Audio:application.id:a.player",
            canonicalId: "a.player",
            displayName: "Z label",
            childLabel: "Only title"
        }
    ];

    const before = AudioModel.groupStreams(streams);
    const after = AudioModel.groupStreams(streams.slice().reverse().map(stream => ({
        ...stream,
        displayName: stream.displayName === "A label" ? "ZZZ renamed" : "AAA renamed",
        childLabel: stream.childLabel === "A title" ? "ZZZ changed" : "AAA changed"
    })));

    assert.deepEqual(before.map(group => group.key), after.map(group => group.key));
    assert.deepEqual(before[1].streams.map(stream => stream.serial), [9001, 9002]);
    assert.deepEqual(after[1].streams.map(stream => stream.serial), [9001, 9002]);
});

test("snapshot signatures ignore live gain but change with graph membership", () => {
    const fixture = graphFixture();
    const resolvePresentation = () => ({ canonicalId: "player", displayName: "Player", iconPath: "icon" });
    const before = AudioModel.buildSnapshot(
        definitions,
        fixture.nodes,
        fixture.links,
        AudioOutStream,
        AudioSink,
        10,
        resolvePresentation
    );

    fixture.nodes.find(node => node.id === 20).audio.volume = 0.12;
    const gainOnly = AudioModel.buildSnapshot(
        definitions,
        fixture.nodes,
        fixture.links,
        AudioOutStream,
        AudioSink,
        10,
        resolvePresentation
    );
    assert.equal(AudioModel.snapshotSignature(before), AudioModel.snapshotSignature(gainOnly));

    fixture.links = fixture.links.map(link => link.sourceId === 70 && link.targetId === 13
        ? { ...link, targetId: 11 }
        : link);
    const moved = AudioModel.buildSnapshot(
        definitions,
        fixture.nodes,
        fixture.links,
        AudioOutStream,
        AudioSink,
        10,
        resolvePresentation
    );
    assert.notEqual(AudioModel.snapshotSignature(before), AudioModel.snapshotSignature(moved));
});

test("WirePlumber's Notification role shares one persistence group", () => {
    const first = application(1, 101, "org.example.First", "First notification");
    const second = application(2, 102, "org.example.Second", "Second notification");
    first.properties["media.role"] = "Notification";
    second.properties["media.role"] = "Notification";

    assert.equal(
        AudioModel.persistentIdentity(first),
        "Output/Audio:media.role:Notification"
    );
    assert.equal(
        AudioModel.persistentIdentity(first),
        AudioModel.persistentIdentity(second)
    );
});
