# Phase 2/3 audio integration evidence

Validated on 2026-07-10 against the flake-pinned PipeWire 1.6.5 and
WirePlumber 0.5.15. The repository-owned `audio-channels-integration`
derivation runs `integration.sh` and `graph-contract.mjs` with isolated runtime,
state, configuration, PipeWire, Pulse, and WirePlumber sockets. It neither
connects to nor mutates the live desktop audio graph.

## Build-time gates

- `audio-channels-pipewire-config` passed the generated drop-in through the
  pinned `pw-config` parser and asserted exactly four ordered loopbacks.
- `audio-channels-wireplumber-lua` compiled the generated policy with Lua 5.4.
- `audio-channels-audioctl` built the installed helper and passed ShellCheck.
- `audio-channels-integration` exercised the production graph, policy, and
  controller in one repeatable isolated derivation.
- The Home Manager and NixOS toplevel checks built successfully with the
  selected `audio-channels` feature.

## Isolated runtime observations

- The test creates one fake PipeWire device with two device-backed playback
  sinks backed by ALSA's `null` PCM. Hardware monitors are disabled, so no real
  device can enter the isolated graph.
- PipeWire creates exactly eight marked nodes: one `Audio/Sink` and one
  `Stream/Output/Audio` bridge for each of System, Game, Voice Chat, and Music.
  Every bridge retains its passive, no-fallback, linger, and fail-closed target
  properties.
- System is the observed default. A native `pw-cat` client and a
  Pulse-compatible `pacat` client both start there, move through all four
  channels through `funforgiven-audioctl`, and are accepted only after the live
  graph shows one authoritative logical target.
- Aggregate bridge gain/mute changes real bridge Props while both application
  streams remain at unity and unmuted. WirePlumber's structured channel gain
  representation is checked rather than assuming the public scalar is stored
  linearly.
- Before a complete isolated stack restart, the native client is saved on
  Music, the Pulse client on Voice Chat, and the System bridge on output B with
  non-default gain/mute. After restarting PipeWire, PipeWire Pulse,
  WirePlumber, both fake sinks, and both clients against the same state
  directory, all four choices return.
- Removing output B leaves System waiting with no bridge link or fallback.
  Recreating the same stable output restores its link. The controller rejects a
  logical Game sink as a hardware target with an actionable error.
- Forgetting only System's saved target selects deterministic output A and
  removes only the dedicated reset metadata. Removing A does not silently fall
  back to B; recreating A recovers the saved route.
- The final structured graph contract validates all node/link references,
  rejects links from a bridge into any logical node, and runs cycle detection
  over the logical sink-to-bridge edges plus live bridge targets.

Real physical hotplug, real-device switching, login/reboot restoration,
Discord/Chromium/Steam active identity capture, UI graph-confirmation timeouts,
and `pw-top` CPU/xrun/quantum/latency inspection remain user-owned
post-activation acceptance tests. Historical WirePlumber keys justify keeping
Discord's Chromium and WebRTC roles distinct; no speculative normalization
rule is enabled.

## Controller boundary

`funforgiven-audioctl` is intentionally a state-free request layer. It validates
two fresh structured `pw-dump` snapshots, live IDs and object serials, exact
generated node names, resolver ambiguity, device backing, cycle safety, the
default metadata object's identity, and the resulting metadata mutation. The
shell must still wait for authoritative link events and surface a timeout.

PipeWire metadata has no compare-and-set operation tying a subject ID to an
expected `object.serial`. A very small destroy/reuse window therefore remains
between final validation and `pw-metadata`; post-validation detects it but
cannot undo an already-issued request. A one-shot libwireplumber client would
still issue the same non-conditional metadata operation, so it would not make
that boundary atomic. This is the accepted phase-one CLI tradeoff.

Likewise, bridge normalization and reset completion are owned by the
WirePlumber hook, not acknowledged as duplicate helper state. The UI remains
graph-authoritative and reports command failure or graph-confirmation timeout.

## Narrow recovery commands

First inspect the graph and obtain the current bridge ID plus `object.serial`:

```sh
wpctl status -n
pw-dump | jq '.[] | select(.type == "PipeWire:Interface:Node") | select(.info.props["funforgiven.audio.kind"] == "bridge") | { id, props: .info.props }'
```

With explicit user intent, reset only one channel's saved hardware target:

```sh
funforgiven-audioctl forget-bridge-target BRIDGE_ID BRIDGE_SERIAL system
```

Reset only that bridge's aggregate gain/mute through its live owner:

```sh
wpctl set-volume BRIDGE_ID 1.0
wpctl set-mute BRIDGE_ID 0
```

Inspect the dedicated state when diagnosing persistence, but do not edit it
while WirePlumber runs:

```sh
sed -n '1,120p' "${XDG_STATE_HOME:-$HOME/.local/state}/wireplumber/funforgiven-channel-output-targets"
```

Never use `wpctl reset --all` or remove unrelated WirePlumber device/profile
state as part of channel recovery.
