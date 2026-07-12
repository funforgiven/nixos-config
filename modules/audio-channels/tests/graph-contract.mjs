import fs from "node:fs";
import { pathToFileURL } from "node:url";

const channelIds = ["system", "game", "voice", "music"];
const channelNodePrefix = "funforgiven.audio.channel.";
const maxGlobalId = 4294967294;
const maxRouteDevice = 2147483647;
const transactionMetadataKeys = new Set([
    "funforgiven.audio.reset-output-target",
    "funforgiven.audio.reset-output-target-commit",
    "funforgiven.audio.reset-output-target-ack",
    "funforgiven.audio.reset-output-target-error",
    "funforgiven.audio.move-output-target",
    "funforgiven.audio.move-output-target-ack",
    "funforgiven.audio.move-output-target-error"
]);

function canonicalGlobalId(value) {
    if (typeof value === "number") {
        return Number.isInteger(value) && value >= 0 && value <= maxGlobalId
            ? String(value)
            : null;
    }
    if (typeof value !== "string" || !/^(0|[1-9][0-9]*)$/.test(value))
        return null;
    if (value.length > 10 || (value.length === 10 && value > String(maxGlobalId)))
        return null;
    return value;
}

function properties(object) {
    return object?.info?.props || {};
}

function propertyIsTrue(value) {
    return value === true || value === 1 || value === "true"
        || value === "yes" || value === "1";
}

function canonicalRouteDevice(value) {
    if (typeof value === "number") {
        return Number.isInteger(value) && value >= 0 && value <= maxRouteDevice
            ? String(value)
            : null;
    }
    if (typeof value !== "string" || !/^(0|[1-9][0-9]*)$/.test(value))
        return null;
    if (value.length > 10 || (value.length === 10 && value > String(maxRouteDevice)))
        return null;
    return value;
}

function routeIsAvailable(route) {
    return String(route?.available ?? "unknown").toLowerCase() !== "no";
}

function endpoint(object, direction) {
    const infoKey = direction === "output" ? "output-node-id" : "input-node-id";
    const propertyKey = direction === "output" ? "link.output.node" : "link.input.node";
    return canonicalGlobalId(object?.info?.[infoKey] ?? object?.info?.props?.[propertyKey]);
}

function expectedChannels(expected) {
    if (!expected || !Array.isArray(expected.channels))
        throw new Error("expected runtime data must contain a channels array");

    const channels = expected.channels.map(channel => ({
        id: String(channel?.id || ""),
        sinkName: String(channel?.sinkName || ""),
        bridgeName: String(channel?.bridgeName || "")
    }));
    if (channels.map(channel => channel.id).join("\0") !== channelIds.join("\0"))
        throw new Error(`expected channel IDs must be ${channelIds.join(", ")}`);
    for (const channel of channels) {
        if (!channel.sinkName || !channel.bridgeName)
            throw new Error(`channel ${channel.id} has an empty sink or bridge name`);
    }
    return channels;
}

function indexGraph(graph) {
    if (!Array.isArray(graph))
        throw new Error("pw-dump did not produce an object array");

    const nodes = new Map();
    const devices = new Map();
    const globalIds = new Set();
    const errors = [];
    for (const object of graph) {
        if (!object || typeof object !== "object") {
            errors.push("pw-dump contains a non-object entry");
            continue;
        }
        const id = canonicalGlobalId(object.id);
        if (id === null) {
            errors.push(`object of type ${String(object.type)} has an invalid global ID`);
            continue;
        }
        if (globalIds.has(id)) {
            errors.push(`duplicate live global ID ${id}`);
            continue;
        }
        globalIds.add(id);
        if (object.type === "PipeWire:Interface:Node")
            nodes.set(id, object);
        else if (object.type === "PipeWire:Interface:Device")
            devices.set(id, object);
    }

    const defaultMetadataObjects = graph.filter(object =>
        object?.type === "PipeWire:Interface:Metadata"
        && object?.props?.["metadata.name"] === "default");
    let defaultMetadata = [];
    if (defaultMetadataObjects.length !== 1) {
        errors.push(`found ${defaultMetadataObjects.length} default metadata objects`);
    } else if (!Array.isArray(defaultMetadataObjects[0].metadata)) {
        errors.push("default metadata object has no structured metadata entries");
    } else {
        defaultMetadata = defaultMetadataObjects[0].metadata;
    }

    const links = [];
    for (const object of graph.filter(item => item?.type === "PipeWire:Interface:Link")) {
        const state = String(object?.info?.state ?? "").toLowerCase();
        if (state === "error" || state === "unlinked") {
            errors.push(`link ${String(object.id)} is ${state}`);
            continue;
        }
        const output = endpoint(object, "output");
        const input = endpoint(object, "input");
        if (output === null || input === null || !nodes.has(output) || !nodes.has(input)) {
            errors.push(`link ${String(object.id)} has a malformed or stale endpoint`);
            continue;
        }
        links.push({ output, input });
    }

    return { nodes, devices, links, defaultMetadata, errors };
}

function addEdge(adjacency, from, to) {
    if (!adjacency.has(from))
        adjacency.set(from, new Set());
    adjacency.get(from).add(to);
}

function reaches(adjacency, start, goal) {
    const pending = [start];
    const visited = new Set();
    while (pending.length > 0) {
        const current = pending.shift();
        if (current === goal)
            return true;
        if (visited.has(current))
            continue;
        visited.add(current);
        for (const next of adjacency.get(current) || [])
            pending.push(next);
    }
    return false;
}

function findCycle(adjacency, nodeIds) {
    const visiting = new Set();
    const visited = new Set();

    function visit(id, trail) {
        if (visiting.has(id))
            return [...trail, id];
        if (visited.has(id))
            return null;
        visiting.add(id);
        for (const next of adjacency.get(id) || []) {
            const cycle = visit(next, [...trail, id]);
            if (cycle)
                return cycle;
        }
        visiting.delete(id);
        visited.add(id);
        return null;
    }

    for (const id of nodeIds) {
        const cycle = visit(id, []);
        if (cycle)
            return cycle;
    }
    return null;
}

function physicalTargetErrors(target, index) {
    if (!target)
        return ["bridge has no unique live target"];

    const props = properties(target);
    const name = props["node.name"];
    const errors = [];
    if (props["media.class"] !== "Audio/Sink")
        errors.push("target is not an Audio/Sink");
    if (String(target?.info?.state ?? "").toLowerCase() === "error")
        errors.push("target node is in the error state");
    if (typeof name !== "string" || name.length === 0)
        errors.push("target has no stable node.name");
    else {
        const resolution = [...index.nodes.values()].filter(node => {
            const nodeProps = properties(node);
            return nodeProps["node.name"] === name || nodeProps["object.path"] === name;
        });
        if (resolution.length !== 1 || resolution[0] !== target)
            errors.push("target node.name is ambiguous across node.name/object.path");
        if (channelNodePrefix && name.startsWith(channelNodePrefix))
            errors.push("target uses the reserved channel node prefix");
        if (!Number.isNaN(Number(name)))
            errors.push("target node.name is numeric-looking");
    }

    const deviceId = canonicalGlobalId(props["device.id"]);
    if (deviceId === null || !index.devices.has(deviceId))
        errors.push("target is not backed by one live PipeWire device");
    if (props["funforgiven.audio.channel"] !== undefined
            || props["funforgiven.audio.kind"] !== undefined)
        errors.push("target is part of the logical channel graph");
    if (propertyIsTrue(props["node.virtual"])
            || propertyIsTrue(props["node.disabled"])
            || propertyIsTrue(props["device.disabled"])
            || propertyIsTrue(props["wireplumber.is-virtual"])
            || propertyIsTrue(props["wireplumber.is-fallback"])
            || propertyIsTrue(props["bluez5.loopback"]))
        errors.push("target is disabled, virtual, or a policy fallback");
    if (props["node.link-group"] !== undefined
            || props["filter.smart"] !== undefined
            || props["filter.smart.name"] !== undefined
            || props["filter.smart.target"] !== undefined)
        errors.push("target is a filter endpoint");
    if (props["factory.name"] === "support.null-audio-sink")
        errors.push("target is a null Audio/Sink");
    return errors;
}

function targetHasAvailableRoutes(target, index) {
    if (!target)
        return false;

    const props = properties(target);
    const profileDevice = canonicalRouteDevice(props["card.profile.device"]);
    const deviceId = canonicalGlobalId(props["device.id"]);
    if (profileDevice === null || deviceId === null)
        return true;

    const device = index.devices.get(deviceId);
    if (!device)
        return true;

    const activeRoutes = Array.isArray(device?.info?.params?.Route)
        ? device.info.params.Route
        : [];
    for (const route of activeRoutes) {
        if (canonicalRouteDevice(route?.device) === profileDevice)
            return routeIsAvailable(route);
    }

    let matchingRoutes = 0;
    const enumeratedRoutes = Array.isArray(device?.info?.params?.EnumRoute)
        ? device.info.params.EnumRoute
        : [];
    for (const route of enumeratedRoutes) {
        const devices = Array.isArray(route?.devices) ? route.devices : [];
        if (!devices.some(value => canonicalRouteDevice(value) === profileDevice))
            continue;
        matchingRoutes += 1;
        if (routeIsAvailable(route))
            return true;
    }
    return matchingRoutes === 0;
}

export function validateRuntimeGraph(graph, expected) {
    const definitions = expectedChannels(expected);
    const index = indexGraph(graph);
    const lingeringTransactions = index.defaultMetadata.filter(entry =>
        transactionMetadataKeys.has(entry?.key));
    if (lingeringTransactions.length !== 0) {
        const locations = lingeringTransactions.map(entry =>
            `${String(entry?.key)}@${String(entry?.subject)}`);
        index.errors.push(
            `default metadata has lingering output-control metadata: ${locations.join(", ")}`);
    }
    const adjacency = new Map();
    for (const link of index.links)
        addEdge(adjacency, link.output, link.input);

    const channels = [];
    for (const definition of definitions) {
        const markedSinks = [...index.nodes.entries()].filter(([, node]) => {
            const props = properties(node);
            return props["funforgiven.audio.channel"] === definition.id
                && props["funforgiven.audio.kind"] === "sink";
        });
        const markedBridges = [...index.nodes.entries()].filter(([, node]) => {
            const props = properties(node);
            return props["funforgiven.audio.channel"] === definition.id
                && props["funforgiven.audio.kind"] === "bridge";
        });
        const errors = [];
        if (markedSinks.length !== 1)
            errors.push(`found ${markedSinks.length} marked logical sinks`);
        if (markedBridges.length !== 1)
            errors.push(`found ${markedBridges.length} marked bridges`);

        const sinkEntry = markedSinks.length === 1 ? markedSinks[0] : null;
        const bridgeEntry = markedBridges.length === 1 ? markedBridges[0] : null;
        if (sinkEntry) {
            const sinkProps = properties(sinkEntry[1]);
            if (sinkProps["node.name"] !== definition.sinkName
                    || sinkProps["media.class"] !== "Audio/Sink"
                    || !propertyIsTrue(sinkProps["node.virtual"]))
                errors.push("logical sink identity, class, or virtual marker is invalid");
        }
        if (bridgeEntry) {
            const bridgeProps = properties(bridgeEntry[1]);
            if (bridgeProps["node.name"] !== definition.bridgeName
                    || bridgeProps["media.class"] !== "Stream/Output/Audio")
                errors.push("bridge identity or media class is invalid");
        }
        if (sinkEntry && bridgeEntry)
            addEdge(adjacency, sinkEntry[0], bridgeEntry[0]);

        channels.push({
            id: definition.id,
            sinkName: definition.sinkName,
            bridgeName: definition.bridgeName,
            sinkId: sinkEntry?.[0] || null,
            bridgeId: bridgeEntry?.[0] || null,
            sinkPresent: sinkEntry !== null,
            bridgePresent: bridgeEntry !== null,
            errors
        });
    }

    for (const channel of channels) {
        const targetIds = channel.bridgeId === null
            ? []
            : [...new Set(index.links
                .filter(link => link.output === channel.bridgeId)
                .map(link => link.input))];
        if (targetIds.length !== 1)
            channel.errors.push(`bridge resolves to ${targetIds.length} live output nodes`);
        const targetId = targetIds.length === 1 ? targetIds[0] : null;
        const target = targetId === null ? null : index.nodes.get(targetId);
        const targetErrors = physicalTargetErrors(target, index);
        const targetPhysical = targetErrors.length === 0;
        const targetAvailable = targetHasAvailableRoutes(target, index);
        const targetReachesBridge = target !== null
            && reaches(adjacency, targetId, channel.bridgeId);
        const targetCycleSafe = target !== null
            && index.errors.length === 0
            && !targetReachesBridge;
        if (!targetPhysical)
            channel.errors.push(...targetErrors);
        if (targetPhysical && !targetAvailable)
            channel.errors.push("target has no available hardware route");
        if (targetReachesBridge)
            channel.errors.push("target reaches its channel bridge and forms a feedback cycle");

        if (channel.bridgeId !== null) {
            const subjectEntries = index.defaultMetadata.filter(entry =>
                canonicalGlobalId(entry?.subject) === channel.bridgeId);
            const targetEntries = subjectEntries.filter(entry => entry?.key === "target.object");
            if (targetEntries.length !== 1) {
                channel.errors.push(`bridge has ${targetEntries.length} target.object metadata entries`);
            } else if (targetEntries[0].type !== "Spa:String"
                    || targetEntries[0].value !== (target ? properties(target)["node.name"] : null)) {
                channel.errors.push("bridge target.object metadata does not name the linked physical target");
            }
        }

        channel.targetConnected = targetIds.length === 1;
        channel.targetId = targetId;
        channel.targetSerial = target ? String(properties(target)["object.serial"] ?? "") : null;
        channel.targetName = target ? properties(target)["node.name"] ?? null : null;
        channel.targetPhysical = targetPhysical;
        channel.targetAvailable = targetAvailable;
        channel.targetCycleSafe = targetCycleSafe;
    }

    const errors = [...index.errors];
    for (const channel of channels) {
        for (const error of channel.errors)
            errors.push(`${channel.id}: ${error}`);
    }
    return {
        ok: errors.length === 0,
        errors,
        channels
    };
}

function validateIntegrationGraph(graph) {
    const expected = {
        channels: channelIds.map(id => ({
            id,
            sinkName: `${channelNodePrefix}${id}`,
            bridgeName: `${channelNodePrefix}${id}.output`
        }))
    };
    const result = validateRuntimeGraph(graph, expected);
    if (!result.ok)
        throw new Error(result.errors.join("; "));

    const index = indexGraph(graph);
    const adjacency = new Map();
    for (const link of index.links)
        addEdge(adjacency, link.output, link.input);
    for (const channel of result.channels)
        addEdge(adjacency, channel.sinkId, channel.bridgeId);
    const cycle = findCycle(adjacency, index.nodes.keys());
    if (cycle)
        throw new Error(`audio graph cycle: ${cycle.join(" -> ")}`);

    for (const outputName of ["funforgiven.test.output.a", "funforgiven.test.output.b"]) {
        const matches = [...index.nodes.values()].filter(node => properties(node)["node.name"] === outputName);
        if (matches.length !== 1)
            throw new Error(`${outputName} has ${matches.length} live nodes`);
        const props = properties(matches[0]);
        if (props["media.class"] !== "Audio/Sink" || propertyIsTrue(props["node.virtual"]))
            throw new Error(`${outputName} is not a non-virtual Audio/Sink`);
        if (matches[0].info?.state === "error")
            throw new Error(`${outputName} entered PipeWire's error state`);
        const deviceId = canonicalGlobalId(props["device.id"]);
        if (deviceId === null || !index.devices.has(deviceId))
            throw new Error(`${outputName} is not backed by one live PipeWire device`);
    }
}

function readJson(path) {
    return JSON.parse(fs.readFileSync(path, "utf8"));
}

function main(args) {
    if (args[0] === "--runtime") {
        if (args.length !== 3)
            throw new Error("usage: graph-contract.mjs --runtime PW_DUMP_JSON EXPECTED_JSON");
        console.log(JSON.stringify(validateRuntimeGraph(readJson(args[1]), readJson(args[2]))));
        return;
    }
    if (args.length !== 1)
        throw new Error("usage: graph-contract.mjs PW_DUMP_JSON");
    validateIntegrationGraph(readJson(args[0]));
    console.log("isolated audio graph contract passed");
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
    try {
        main(process.argv.slice(2));
    } catch (error) {
        console.error(error instanceof Error ? error.message : String(error));
        process.exitCode = 1;
    }
}
