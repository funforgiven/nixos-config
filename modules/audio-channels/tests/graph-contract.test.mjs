import assert from "node:assert/strict";
import test from "node:test";

import { validateRuntimeGraph } from "./graph-contract.mjs";

const definitions = ["system", "game", "voice", "music"].map((id, index) => ({
    id,
    sinkName: `funforgiven.audio.channel.${id}`,
    bridgeName: `funforgiven.audio.channel.${id}.output`,
    sinkId: index * 2 + 1,
    bridgeId: index * 2 + 2
}));

function node(id, props) {
    return {
        id,
        type: "PipeWire:Interface:Node",
        info: { props }
    };
}

function link(id, output, input, state = "active") {
    return {
        id,
        type: "PipeWire:Interface:Link",
        info: {
            state,
            props: {
                "link.output.node": output,
                "link.input.node": input
            }
        }
    };
}

function fixture() {
    const graph = [
        {
            id: 50,
            type: "PipeWire:Interface:Device",
            info: {
                props: { "device.name": "test-device" },
                params: {
                    EnumRoute: [{ devices: [0], available: "yes" }]
                }
            }
        },
        node(40, {
            "node.name": "test-output",
            "object.serial": 400,
            "media.class": "Audio/Sink",
            "device.id": 50,
            "card.profile.device": 0
        })
    ];
    for (const definition of definitions) {
        graph.push(node(definition.sinkId, {
            "node.name": definition.sinkName,
            "object.serial": definition.sinkId + 100,
            "media.class": "Audio/Sink",
            "node.virtual": true,
            "funforgiven.audio.channel": definition.id,
            "funforgiven.audio.kind": "sink"
        }));
        graph.push(node(definition.bridgeId, {
            "node.name": definition.bridgeName,
            "object.serial": definition.bridgeId + 100,
            "media.class": "Stream/Output/Audio",
            "funforgiven.audio.channel": definition.id,
            "funforgiven.audio.kind": "bridge"
        }));
        graph.push(link(100 + definition.bridgeId, definition.bridgeId, 40));
    }
    graph.push({
        id: 60,
        type: "PipeWire:Interface:Metadata",
        props: { "metadata.name": "default" },
        metadata: definitions.map(definition => ({
            subject: definition.bridgeId,
            key: "target.object",
            type: "Spa:String",
            value: "test-output"
        }))
    });
    return graph;
}

const expected = {
    channels: definitions.map(({ id, sinkName, bridgeName }) => ({ id, sinkName, bridgeName }))
};

test("runtime contract accepts four device-backed acyclic bridge targets", () => {
    const result = validateRuntimeGraph(fixture(), expected);
    assert.equal(result.ok, true);
    assert.equal(result.channels.length, 4);
    assert.ok(result.channels.every(channel =>
        channel.targetPhysical && channel.targetAvailable && channel.targetCycleSafe));
});

test("an unavailable active Route overrides an available EnumRoute", () => {
    const graph = fixture();
    graph.find(object => object.id === 50).info.params.Route = [
        { device: 0, available: "no" }
    ];
    const result = validateRuntimeGraph(graph, expected);

    assert.equal(result.ok, false);
    assert.ok(result.channels.every(channel => channel.targetPhysical === true));
    assert.ok(result.channels.every(channel => channel.targetAvailable === false));
    assert.match(result.errors.join(" "), /no available hardware route/);
});

test("EnumRoute requires one non-no match when no active Route matches", () => {
    const unavailableGraph = fixture();
    unavailableGraph.find(object => object.id === 50).info.params.EnumRoute = [
        { devices: [0], available: "no" },
        { devices: [0, 1], available: "no" }
    ];
    const unavailable = validateRuntimeGraph(unavailableGraph, expected);
    assert.equal(unavailable.ok, false);
    assert.ok(unavailable.channels.every(channel => channel.targetAvailable === false));

    const availableGraph = fixture();
    availableGraph.find(object => object.id === 50).info.params.EnumRoute = [
        { devices: [0], available: "no" },
        { devices: [0, 1], available: "unknown" }
    ];
    const available = validateRuntimeGraph(availableGraph, expected);
    assert.equal(available.ok, true);
    assert.ok(available.channels.every(channel => channel.targetAvailable === true));
});

test("profiles without matching routes remain available", () => {
    const graph = fixture();
    const target = graph.find(object => object.id === 40);
    const device = graph.find(object => object.id === 50);
    device.info.params.EnumRoute = [{ devices: [1], available: "no" }];

    let result = validateRuntimeGraph(graph, expected);
    assert.equal(result.ok, true);
    assert.ok(result.channels.every(channel => channel.targetAvailable === true));

    delete target.info.props["card.profile.device"];
    device.info.params.EnumRoute = [{ devices: [0], available: "no" }];
    result = validateRuntimeGraph(graph, expected);
    assert.equal(result.ok, true);
    assert.ok(result.channels.every(channel => channel.targetAvailable === true));
});

test("runtime contract rejects a virtual bridge target", () => {
    const graph = fixture();
    graph.find(object => object.id === 40).info.props["node.virtual"] = true;
    const result = validateRuntimeGraph(graph, expected);
    assert.equal(result.ok, false);
    assert.ok(result.channels.every(channel => channel.targetPhysical === false));
});

test("runtime contract rejects disabled bridge targets", () => {
    for (const key of ["node.disabled", "device.disabled"]) {
        const graph = fixture();
        graph.find(object => object.id === 40).info.props[key] = true;
        const result = validateRuntimeGraph(graph, expected);
        assert.equal(result.ok, false);
        assert.ok(result.channels.every(channel => channel.targetPhysical === false));
        assert.match(result.errors.join(" "), /disabled/);
    }
});

test("runtime contract rejects an error-state target", () => {
    const graph = fixture();
    graph.find(object => object.id === 40).info.state = "error";
    const result = validateRuntimeGraph(graph, expected);
    assert.equal(result.ok, false);
    assert.ok(result.channels.every(channel => channel.targetPhysical === false));
    assert.match(result.errors.join(" "), /error state/);
});

test("runtime contract rejects unusable links without inventing cycles", () => {
    const graph = fixture();
    graph.find(object => object.type === "PipeWire:Interface:Link").info.state = "unlinked";
    const result = validateRuntimeGraph(graph, expected);
    assert.equal(result.ok, false);
    assert.match(result.errors.join(" "), /link .* is unlinked/);
    assert.doesNotMatch(result.errors.join(" "), /feedback cycle/);
});

test("runtime contract requires normalized target metadata", () => {
    const graph = fixture();
    const metadata = graph.find(object => object.type === "PipeWire:Interface:Metadata").metadata;
    metadata.find(entry => entry.subject === definitions[0].bridgeId).value = "other-output";
    const result = validateRuntimeGraph(graph, expected);
    assert.equal(result.ok, false);
    assert.match(result.errors.join(" "), /does not name the linked physical target/);
});

for (const key of [
    "funforgiven.audio.reset-output-target",
    "funforgiven.audio.reset-output-target-commit",
    "funforgiven.audio.reset-output-target-ack",
    "funforgiven.audio.reset-output-target-error",
    "funforgiven.audio.move-output-target",
    "funforgiven.audio.move-output-target-ack",
    "funforgiven.audio.move-output-target-error"
]) {
    for (const [description, subject] of [
        ["bridge", definitions[1].bridgeId],
        ["orphan", 4294967294]
    ]) {
        test(`runtime contract rejects lingering ${description} ${key} metadata`, () => {
            const graph = fixture();
            graph.find(object => object.type === "PipeWire:Interface:Metadata").metadata.push({
                subject,
                key,
                type: "Spa:String",
                value: "1:2:3:4"
            });
            const result = validateRuntimeGraph(graph, expected);
            assert.equal(result.ok, false);
            assert.match(result.errors.join(" "), /lingering output-control metadata/);
        });
    }
}

test("runtime contract rejects a target path back to its bridge", () => {
    const graph = fixture();
    graph.push(link(200, 40, definitions[0].sinkId));
    const result = validateRuntimeGraph(graph, expected);
    assert.equal(result.ok, false);
    assert.equal(result.channels[0].targetCycleSafe, false);
    assert.match(result.channels[0].errors.join(" "), /feedback cycle/);
});

test("runtime contract rejects missing device backing and stale links", () => {
    const graph = fixture().filter(object => object.type !== "PipeWire:Interface:Device");
    graph.push(link(201, 999, definitions[0].sinkId));
    const result = validateRuntimeGraph(graph, expected);
    assert.equal(result.ok, false);
    assert.ok(result.errors.some(error => /malformed or stale endpoint/.test(error)));
    assert.ok(result.channels.every(channel => channel.targetPhysical === false));
    assert.doesNotMatch(result.errors.join(" "), /feedback cycle/);
});
