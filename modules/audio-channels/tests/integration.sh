#!/usr/bin/env bash

set -euo pipefail

: "${PIPEWIRE_TEST_CONFIG:?PIPEWIRE_TEST_CONFIG is required}"
: "${WIREPLUMBER_TEST_DATA_DIRS:?WIREPLUMBER_TEST_DATA_DIRS is required}"
: "${WIREPLUMBER_FAULT_TEST_DATA_DIRS:?WIREPLUMBER_FAULT_TEST_DATA_DIRS is required}"
: "${AUDIOCTL:?AUDIOCTL is required}"
: "${AUDIOCTL_INTERRUPT_HELPER:?AUDIOCTL_INTERRUPT_HELPER is required}"
: "${AUDIO_GRAPH_CHECK:?AUDIO_GRAPH_CHECK is required}"

readonly work="$TMPDIR/funforgiven-audio-integration"
readonly graph="$work/graph.json"
readonly native_app="funforgiven.test.native"
readonly pulse_app="funforgiven.test.pulse"
readonly fake_device_name="funforgiven.test.device"
readonly fake_output_prefix="funforgiven.test.output"
readonly -a channel_ids=(system game voice music)

export HOME="$work/home"
export XDG_RUNTIME_DIR="$work/runtime"
export XDG_STATE_HOME="$work/state"
export XDG_CONFIG_HOME="$work/config"
export PIPEWIRE_CONFIG_DIR="$PIPEWIRE_TEST_CONFIG/share/pipewire"
export XDG_DATA_DIRS="$WIREPLUMBER_TEST_DATA_DIRS"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$work/no-session-bus"
export DBUS_SYSTEM_BUS_ADDRESS="unix:path=$work/no-system-bus"
export PULSE_SERVER="unix:$XDG_RUNTIME_DIR/pulse/native"

mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$XDG_STATE_HOME" "$XDG_CONFIG_HOME"
chmod 0700 "$XDG_RUNTIME_DIR"

generation=0
pw_pid=""
pulse_server_pid=""
wp_pid=""
fixture_pid=""
native_pid=""
pulse_client_pid=""
paused_move_pid=""
fixture_fd_open=false

stop_pid() {
  local pid=${1:-}
  if [[ -n $pid ]]; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi
}

cleanup() {
  set +e
  stop_pid "$paused_move_pid"
  stop_pid "$native_pid"
  stop_pid "$pulse_client_pid"
  stop_pid "$wp_pid"
  stop_pid "$pulse_server_pid"
  if [[ $fixture_fd_open == true ]]; then
    exec 3>&-
    fixture_fd_open=false
  fi
  stop_pid "$fixture_pid"
  stop_pid "$pw_pid"
}
trap cleanup EXIT

fail() {
  printf 'audio integration failure: %s\n' "$1" >&2
  if dump_graph 2>/dev/null; then
    jq '[
      .[]
      | select(.type == "PipeWire:Interface:Node")
      | select(.info.props["funforgiven.audio.kind"] == "bridge")
      | {
          channel: .info.props["funforgiven.audio.channel"],
          id,
          props: .info.params.Props[0]
        }
    ]' "$graph" >&2 || true
  fi
  for log in "$work"/*.log; do
    [[ -f $log ]] || continue
    printf '\n%s\n' "== $log ==" >&2
    tail -120 "$log" >&2 || true
  done
  exit 1
}

wait_for() {
  local description=$1
  shift
  local attempt
  for ((attempt = 0; attempt < 160; attempt++)); do
    if "$@"; then
      return 0
    fi
    sleep 0.05
  done
  fail "timed out waiting for $description"
}

dump_graph() {
  timeout 5 pw-dump >"$graph.next" 2>/dev/null || return 1
  mv "$graph.next" "$graph"
}

node_present() {
  local name=$1
  dump_graph || return 1
  jq -e --arg name "$name" '
    [.[] | select(.type == "PipeWire:Interface:Node" and .info.props["node.name"] == $name)]
    | length == 1
  ' "$graph" >/dev/null
}

node_absent() {
  local name=$1
  dump_graph || return 1
  jq -e --arg name "$name" '
    [.[] | select(.type == "PipeWire:Interface:Node" and .info.props["node.name"] == $name)]
    | length == 0
  ' "$graph" >/dev/null
}

node_identity_absent() {
  local id=$1
  local serial=$2
  dump_graph || return 1
  jq -e --arg id "$id" --arg serial "$serial" '
    [
      .[]
      | select(.type == "PipeWire:Interface:Node")
      | select((.id | tostring) == $id)
      | select((.info.props["object.serial"] | tostring) == $serial)
    ] | length == 0
  ' "$graph" >/dev/null
}

device_present() {
  dump_graph || return 1
  jq -e --arg name "$fake_device_name" '
    [.[] | select(.type == "PipeWire:Interface:Device" and .info.props["device.name"] == $name)]
    | length == 1
  ' "$graph" >/dev/null
}

topology_ready() {
  dump_graph || return 1
  jq -e --argjson channels '["system", "game", "voice", "music"]' '
    [
      .[]
      | select(.type == "PipeWire:Interface:Node")
      | select(.info.props["funforgiven.audio.channel"] != null)
      | .info.props
    ] as $nodes
    | ($nodes | length) == 8
      and ([$nodes[] | select(."funforgiven.audio.kind" == "sink") | ."funforgiven.audio.channel"] | sort) == ($channels | sort)
      and ([$nodes[] | select(."funforgiven.audio.kind" == "bridge") | ."funforgiven.audio.channel"] | sort) == ($channels | sort)
  ' "$graph" >/dev/null
}

metadata_ready() {
  dump_graph || return 1
  jq -e '
    [.[] | select(.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default")]
    | length == 1
  ' "$graph" >/dev/null
}

metadata_absent() {
  dump_graph || return 1
  jq -e '
    [.[] | select(.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default")]
    | length == 0
  ' "$graph" >/dev/null
}

default_is_system() {
  dump_graph || return 1
  jq -e '
    [
      .[]
      | select(.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default")
      | .metadata[]?
      | select(.subject == 0 and .key == "default.audio.sink")
      | .value
      | if type == "string" then fromjson? else . end
      | .name
    ] == ["funforgiven.audio.channel.system"]
  ' "$graph" >/dev/null
}

load_node_ref() {
  local name=$1
  dump_graph || fail "could not read the graph while resolving $name"
  local -a refs=()
  mapfile -t refs < <(jq -r --arg name "$name" '
    .[]
    | select(.type == "PipeWire:Interface:Node" and .info.props["node.name"] == $name)
    | [.id, .info.props["object.serial"]]
    | @tsv
  ' "$graph")
  ((${#refs[@]} == 1)) || fail "expected exactly one live node named $name"
  IFS=$'\t' read -r ref_id ref_serial <<<"${refs[0]}"
}

load_stream_ref() {
  local application_id=$1
  dump_graph || fail "could not read the graph while resolving stream $application_id"
  local -a refs=()
  mapfile -t refs < <(jq -r --arg app "$application_id" '
    .[]
    | select(.type == "PipeWire:Interface:Node")
    | select(.info.props["media.class"] == "Stream/Output/Audio")
    | select(.info.props["application.id"] == $app)
    | [.id, .info.props["object.serial"]]
    | @tsv
  ' "$graph")
  ((${#refs[@]} == 1)) || fail "expected exactly one live playback stream for $application_id"
  IFS=$'\t' read -r ref_id ref_serial <<<"${refs[0]}"
}

stream_present() {
  local application_id=$1
  dump_graph || return 1
  jq -e --arg app "$application_id" '
    [
      .[]
      | select(.type == "PipeWire:Interface:Node")
      | select(.info.props["media.class"] == "Stream/Output/Audio")
      | select(.info.props["application.id"] == $app)
    ] | length == 1
  ' "$graph" >/dev/null
}

stream_absent() {
  local application_id=$1
  dump_graph || return 1
  jq -e --arg app "$application_id" '
    [
      .[]
      | select(.type == "PipeWire:Interface:Node")
      | select(.info.props["application.id"] == $app)
    ] | length == 0
  ' "$graph" >/dev/null
}

stream_linked_to() {
  local application_id=$1
  local channel=$2
  dump_graph || return 1
  jq -e --arg app "$application_id" --arg channel "$channel" '
    . as $graph
    | [
        .[]
        | select(.type == "PipeWire:Interface:Node")
        | select(.info.props["media.class"] == "Stream/Output/Audio")
        | select(.info.props["application.id"] == $app)
      ] as $streams
    | [
        .[]
        | select(.type == "PipeWire:Interface:Node")
        | select(.info.props["funforgiven.audio.channel"] == $channel)
        | select(.info.props["funforgiven.audio.kind"] == "sink")
      ] as $sinks
    | ($streams | length) == 1
      and ($sinks | length) == 1
      and ([
        $graph[]
        | select(.type == "PipeWire:Interface:Link")
        | select((.info.props["link.output.node"] | tostring) == ($streams[0].id | tostring))
        | .info.props["link.input.node"] | tostring
      ] | unique) == [($sinks[0].id | tostring)]
  ' "$graph" >/dev/null
}

bridge_target_is() {
  local channel=$1
  local output_name=$2
  dump_graph || return 1
  jq -e --arg channel "$channel" --arg output "$output_name" '
    . as $graph
    | [
        .[]
        | select(.type == "PipeWire:Interface:Node")
        | select(.info.props["funforgiven.audio.channel"] == $channel)
        | select(.info.props["funforgiven.audio.kind"] == "bridge")
      ] as $bridges
    | [.[] | select(.type == "PipeWire:Interface:Node" and .info.props["node.name"] == $output)] as $outputs
    | ($bridges | length) == 1
      and ($outputs | length) == 1
      and ([
        $graph[]
        | select(.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default")
        | .metadata[]?
        | select((.subject | tostring) == ($bridges[0].id | tostring))
        | select(.key == "target.object")
        | select(.type == "Spa:String" and .value == $output)
      ] | length) == 1
      and ([
        $graph[]
        | select(.type == "PipeWire:Interface:Link")
        | select((.info.props["link.output.node"] | tostring) == ($bridges[0].id | tostring))
        | .info.props["link.input.node"] | tostring
      ] | unique) == [($outputs[0].id | tostring)]
  ' "$graph" >/dev/null
}

bridge_waiting_for() {
  local channel=$1
  local output_name=$2
  dump_graph || return 1
  jq -e --arg channel "$channel" --arg output "$output_name" '
    . as $graph
    | [
        .[]
        | select(.type == "PipeWire:Interface:Node")
        | select(.info.props["funforgiven.audio.channel"] == $channel)
        | select(.info.props["funforgiven.audio.kind"] == "bridge")
      ] as $bridges
    | ($bridges | length) == 1
      and ([
        $graph[]
        | select(.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default")
        | .metadata[]?
        | select((.subject | tostring) == ($bridges[0].id | tostring))
        | select(.key == "target.object")
        | select(.type == "Spa:String" and .value == $output)
      ] | length) == 1
      and ([
        $graph[]
        | select(.type == "PipeWire:Interface:Link")
        | select((.info.props["link.output.node"] | tostring) == ($bridges[0].id | tostring))
      ] | length) == 0
  ' "$graph" >/dev/null
}

reset_metadata_absent() {
  local channel=$1
  dump_graph || return 1
  jq -e --arg channel "$channel" '
    . as $graph
    | [
        .[]
        | select(.type == "PipeWire:Interface:Node")
        | select(.info.props["funforgiven.audio.channel"] == $channel)
        | select(.info.props["funforgiven.audio.kind"] == "bridge")
      ] as $bridges
    | ($bridges | length) == 1
      and ([
        $graph[]
        | select(.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default")
        | .metadata[]?
        | select((.subject | tostring) == ($bridges[0].id | tostring))
        | select(
            .key == "funforgiven.audio.reset-output-target"
            or .key == "funforgiven.audio.reset-output-target-commit"
            or .key == "funforgiven.audio.reset-output-target-ack"
            or .key == "funforgiven.audio.reset-output-target-error"
          )
      ] | length) == 0
  ' "$graph" >/dev/null
}

transaction_metadata_absent() {
  dump_graph || return 1
  jq -e '
    [
      .[]
      | select(.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default")
      | .metadata[]?
      | select(.key == "funforgiven.audio.reset-output-target"
          or .key == "funforgiven.audio.reset-output-target-commit"
          or .key == "funforgiven.audio.reset-output-target-ack"
          or .key == "funforgiven.audio.reset-output-target-error"
          or .key == "funforgiven.audio.move-output-target"
          or .key == "funforgiven.audio.move-output-target-ack"
          or .key == "funforgiven.audio.move-output-target-error")
    ] | length == 0
  ' "$graph" >/dev/null
}

reset_metadata_is() {
  local bridge_id=$1
  local key=$2
  local expected=$3
  dump_graph || return 1
  jq -e \
    --arg subject "$bridge_id" \
    --arg key "$key" \
    --arg expected "$expected" '
    [
      .[]
      | select(.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default")
      | .metadata[]?
      | select((.subject | tostring) == $subject)
      | select(.key == $key and .type == "Spa:String" and .value == $expected)
    ] | length == 1
  ' "$graph" >/dev/null
}

target_metadata_is() {
  reset_metadata_is "$1" target.object "$2"
}

reset_request_present() {
  local channel=$1
  dump_graph || return 1
  jq -e --arg channel "$channel" '
    . as $graph
    | [
        .[]
        | select(.type == "PipeWire:Interface:Node")
        | select(.info.props["funforgiven.audio.channel"] == $channel)
        | select(.info.props["funforgiven.audio.kind"] == "bridge")
      ] as $bridges
    | ($bridges | length) == 1
      and any(
        $graph[]
        | select(.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default")
        | .metadata[]?;
        (.subject | tostring) == ($bridges[0].id | tostring)
        and .key == "funforgiven.audio.reset-output-target"
      )
  ' "$graph" >/dev/null
}

move_metadata_absent() {
  local channel=$1
  dump_graph || return 1
  jq -e --arg channel "$channel" '
    . as $graph
    | [
        .[]
        | select(.type == "PipeWire:Interface:Node")
        | select(.info.props["funforgiven.audio.channel"] == $channel)
        | select(.info.props["funforgiven.audio.kind"] == "bridge")
      ] as $bridges
    | ($bridges | length) == 1
      and ([
        $graph[]
        | select(.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default")
        | .metadata[]?
        | select((.subject | tostring) == ($bridges[0].id | tostring))
        | select(
            .key == "funforgiven.audio.move-output-target"
            or .key == "funforgiven.audio.move-output-target-ack"
            or .key == "funforgiven.audio.move-output-target-error"
          )
      ] | length) == 0
  ' "$graph" >/dev/null
}

move_error_is() {
  local bridge_id=$1
  local expected=$2
  dump_graph || return 1
  jq -e --arg subject "$bridge_id" --arg expected "$expected" '
    [
      .[]
      | select(.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default")
      | .metadata[]?
      | select((.subject | tostring) == $subject)
      | select(.key == "funforgiven.audio.move-output-target-error")
      | select(.type == "Spa:String" and .value == $expected)
    ] | length == 1
  ' "$graph" >/dev/null
}

move_request_is() {
  local bridge_id=$1
  local expected=$2
  dump_graph || return 1
  jq -e --arg subject "$bridge_id" --arg expected "$expected" '
    [
      .[]
      | select(.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default")
      | .metadata[]?
      | select((.subject | tostring) == $subject)
      | select(.key == "funforgiven.audio.move-output-target")
      | select(.type == "Spa:String" and .value == $expected)
    ] | length == 1
  ' "$graph" >/dev/null
}

move_request_present() {
  local channel=$1
  dump_graph || return 1
  jq -e --arg channel "$channel" '
    . as $graph
    | [
        .[]
        | select(.type == "PipeWire:Interface:Node")
        | select(.info.props["funforgiven.audio.channel"] == $channel)
        | select(.info.props["funforgiven.audio.kind"] == "bridge")
      ] as $bridges
    | ($bridges | length) == 1
      and any(
        $graph[]
        | select(.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default")
        | .metadata[]?;
        (.subject | tostring) == ($bridges[0].id | tostring)
        and .key == "funforgiven.audio.move-output-target"
      )
  ' "$graph" >/dev/null
}

move_ack_is() {
  local bridge_id=$1
  local expected=$2
  dump_graph || return 1
  jq -e --arg subject "$bridge_id" --arg expected "$expected" '
    [
      .[]
      | select(.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default")
      | .metadata[]?
      | select((.subject | tostring) == $subject)
      | select(.key == "funforgiven.audio.move-output-target-ack")
      | select(.type == "Spa:String" and .value == $expected)
    ] | length == 1
  ' "$graph" >/dev/null
}

state_file_present() {
  find "$XDG_STATE_HOME" -type f -print -quit | grep -q .
}

clear_move_metadata() {
  local bridge_id=$1
  local key
  for key in \
    funforgiven.audio.move-output-target \
    funforgiven.audio.move-output-target-ack \
    funforgiven.audio.move-output-target-error; do
    pw-metadata -n default -d -- "$bridge_id" "$key" >/dev/null
  done
}

clear_reset_metadata() {
  local bridge_id=$1
  local key
  for key in \
    funforgiven.audio.reset-output-target \
    funforgiven.audio.reset-output-target-commit \
    funforgiven.audio.reset-output-target-ack \
    funforgiven.audio.reset-output-target-error; do
    pw-metadata -n default -d -- "$bridge_id" "$key" >/dev/null
  done
}

bridge_props_are() {
  local channel=$1
  local expected_channel_volume=$2
  local expected_mute=$3
  dump_graph || return 1
  jq -e --arg channel "$channel" --argjson volume "$expected_channel_volume" --argjson mute "$expected_mute" '
    [
      .[]
      | select(.type == "PipeWire:Interface:Node")
      | select(.info.props["funforgiven.audio.channel"] == $channel)
      | select(.info.props["funforgiven.audio.kind"] == "bridge")
      | .info.params.Props[0]
    ] as $props
    | ($props | length) == 1
      and $props[0].mute == $mute
      and all($props[0].channelVolumes[]; ((. - $volume) | fabs) < 0.005)
  ' "$graph" >/dev/null
}

stream_props_are_unity() {
  local application_id=$1
  dump_graph || return 1
  jq -e --arg app "$application_id" '
    [
      .[]
      | select(.type == "PipeWire:Interface:Node")
      | select(.info.props["application.id"] == $app)
      | .info.params.Props[0]
    ] as $props
    | ($props | length) == 1
      and $props[0].mute == false
      and all($props[0].channelVolumes[]; ((. - 1.0) | fabs) < 0.005)
  ' "$graph" >/dev/null
}

run_graph_contract() {
  dump_graph || fail "could not capture the graph contract input"
  node "$AUDIO_GRAPH_CHECK" "$graph"
}

start_pipewire() {
  generation=$((generation + 1))
  pipewire >"$work/pipewire-$generation.log" 2>&1 &
  pw_pid=$!
  wait_for "isolated PipeWire socket" test -S "$XDG_RUNTIME_DIR/pipewire-0"

  pipewire-pulse >"$work/pipewire-pulse-$generation.log" 2>&1 &
  pulse_server_pid=$!
  wait_for "isolated PipeWire Pulse socket" test -S "$XDG_RUNTIME_DIR/pulse/native"
}

start_fixture() {
  local fifo="$work/pw-cli-$generation.in"
  rm -f "$fifo"
  mkfifo "$fifo"
  exec 3<>"$fifo"
  fixture_fd_open=true
  pw-cli <"$fifo" >"$work/pw-cli-$generation.log" 2>&1 &
  fixture_pid=$!
  sleep 0.2

  printf '%s\n' \
    'create-device spa-device-factory { factory.name = "api.alsa.pcm.device" api.alsa.path = "null" device.name = "funforgiven.test.device" object.linger = true }' >&3
  wait_for "fake PipeWire device" device_present
  device_id=$(jq -r --arg name "$fake_device_name" '
    .[] | select(.type == "PipeWire:Interface:Device" and .info.props["device.name"] == $name) | .id
  ' "$graph")
  create_output a
  create_output b
  create_output disabled device.disabled 1000
}

create_output() {
  local suffix=$1
  local availability_property=${2:-}
  local priority=${3:-200}
  local name="$fake_output_prefix.$suffix"
  local availability=""
  if [[ -n $availability_property ]]; then
    availability="$availability_property = true"
  fi
  printf 'create-node adapter { factory.name = "api.alsa.pcm.sink" api.alsa.path = "null" api.alsa.disable-mmap = true api.alsa.disable-batch = true node.name = "%s" node.description = "Test Output %s" media.class = "Audio/Sink" device.id = %s priority.session = %s object.linger = true audio.format = "S16LE" audio.rate = 48000 audio.channels = 2 audio.position = [ FL FR ] %s }\n' \
    "$name" "$suffix" "$device_id" "$priority" "$availability" >&3
  wait_for "$name" node_present "$name"
}

destroy_output() {
  local suffix=$1
  local name="$fake_output_prefix.$suffix"
  load_node_ref "$name"
  printf 'destroy %s\n' "$ref_id" >&3
  wait_for "$name removal" node_absent "$name"
}

start_wireplumber() {
  local fault=${1:-}
  local data_dirs=$WIREPLUMBER_TEST_DATA_DIRS
  local log_suffix=""
  if [[ -n $fault ]]; then
    data_dirs=$WIREPLUMBER_FAULT_TEST_DATA_DIRS
    log_suffix="-$fault"
  fi
  FUNFORGIVEN_AUDIO_POLICY_TEST_FAULT="$fault" \
    XDG_DATA_DIRS="$data_dirs" \
    wireplumber -p policy \
    >"$work/wireplumber-$generation$log_suffix.log" 2>&1 &
  wp_pid=$!
  wait_for "default WirePlumber metadata" metadata_ready
  wait_for "four-channel topology" topology_ready
  wait_for "System default sink" default_is_system
}

restart_wireplumber() {
  local fault=${1:-}
  stop_pid "$wp_pid"
  wp_pid=""
  wait_for "old default WirePlumber metadata removal" metadata_absent
  start_wireplumber "$fault"
}

start_stack() {
  start_pipewire
  start_fixture
  start_wireplumber
}

stop_clients() {
  stop_pid "$native_pid"
  stop_pid "$pulse_client_pid"
  native_pid=""
  pulse_client_pid=""
  wait_for "native stream removal" stream_absent "$native_app"
  wait_for "Pulse stream removal" stream_absent "$pulse_app"
}

stop_stack() {
  stop_pid "$wp_pid"
  wp_pid=""
  stop_pid "$pulse_server_pid"
  pulse_server_pid=""
  if [[ $fixture_fd_open == true ]]; then
    exec 3>&-
    fixture_fd_open=false
  fi
  stop_pid "$fixture_pid"
  fixture_pid=""
  stop_pid "$pw_pid"
  pw_pid=""
  wait_for "PipeWire socket removal" test ! -S "$XDG_RUNTIME_DIR/pipewire-0"
}

start_clients() {
  pw-cat --playback --raw --rate 48000 --channels 2 --format s16 \
    --properties '{ application.id = "funforgiven.test.native" application.name = "Funforgiven Native Test" node.name = "funforgiven.test.native.stream" }' \
    /dev/zero >"$work/native-$generation.log" 2>&1 &
  native_pid=$!

  pacat --playback --raw --rate=48000 --channels=2 --format=s16le \
    --client-name="Funforgiven Pulse Test" \
    --stream-name="Funforgiven Pulse Stream" \
    --property=application.id="$pulse_app" \
    /dev/zero >"$work/pulse-client-$generation.log" 2>&1 &
  pulse_client_pid=$!

  wait_for "native playback stream" stream_present "$native_app"
  wait_for "Pulse-compatible playback stream" stream_present "$pulse_app"
}

move_stream() {
  local application_id=$1
  local channel=$2
  load_stream_ref "$application_id"
  timeout 10 "$AUDIOCTL" move-stream "$ref_id" "$ref_serial" "$channel"
  wait_for "$application_id route to $channel" stream_linked_to "$application_id" "$channel"
}

move_bridge() {
  local channel=$1
  local output_name=$2
  load_node_ref "funforgiven.audio.channel.$channel.output"
  local bridge_id=$ref_id
  local bridge_serial=$ref_serial
  load_node_ref "$output_name"
  timeout 10 "$AUDIOCTL" move-bridge \
    "$bridge_id" "$bridge_serial" "$channel" "$ref_id" "$ref_serial"
  wait_for "$channel bridge route to $output_name" bridge_target_is "$channel" "$output_name"
}

forget_bridge_target() {
  local channel=$1
  load_node_ref "funforgiven.audio.channel.$channel.output"
  timeout 10 "$AUDIOCTL" forget-bridge-target "$ref_id" "$ref_serial" "$channel"
}

start_paused_bridge_move() {
  local name=$1
  local channel=$2
  local output_name=$3
  local phase=$4
  local marker="$work/$name.marker"
  local release="$work/$name.release"

  rm -f "$marker" "$release"
  load_node_ref "funforgiven.audio.channel.$channel.output"
  local bridge_id=$ref_id
  local bridge_serial=$ref_serial
  load_node_ref "$output_name"
  AUDIOCTL_SOURCE="$AUDIOCTL" \
    AUDIOCTL_PAUSE_MARKER="$marker" \
    AUDIOCTL_PAUSE_PHASE="$phase" \
    AUDIOCTL_PAUSE_RELEASE="$release" \
    bash "$AUDIOCTL_INTERRUPT_HELPER" \
    move-bridge "$bridge_id" "$bridge_serial" "$channel" "$ref_id" "$ref_serial" \
    >"$work/$name.log" 2>&1 &
  paused_move_pid=$!
  paused_move_marker=$marker
  paused_move_release=$release
  wait_for "$name post-request pause" test -f "$paused_move_marker"
}

start_paused_reset() {
  local name=$1
  local channel=$2
  local phase=$3
  local marker="$work/$name.marker"
  local release="$work/$name.release"

  rm -f "$marker" "$release"
  load_node_ref "funforgiven.audio.channel.$channel.output"
  AUDIOCTL_SOURCE="$AUDIOCTL" \
    AUDIOCTL_PAUSE_MARKER="$marker" \
    AUDIOCTL_PAUSE_PHASE="$phase" \
    AUDIOCTL_PAUSE_RELEASE="$release" \
    bash "$AUDIOCTL_INTERRUPT_HELPER" \
    forget-bridge-target "$ref_id" "$ref_serial" "$channel" \
    >"$work/$name.log" 2>&1 &
  paused_move_pid=$!
  paused_move_marker=$marker
  paused_move_release=$release
  wait_for "$name request pause" test -f "$paused_move_marker"
}

printf '%s\n' 'starting isolated four-channel audio integration test'
start_stack
for channel in "${channel_ids[@]}"; do
  wait_for "$channel neutral output" bridge_target_is "$channel" "$fake_output_prefix.a"
done
run_graph_contract

wait_for "WirePlumber channel state" state_file_present
load_node_ref funforgiven.audio.channel.system.output
durable_bridge_id=$ref_id
durable_bridge_serial=$ref_serial
load_node_ref "$fake_output_prefix.b"
durable_target_id=$ref_id
durable_target_serial=$ref_serial

start_paused_bridge_move \
  interrupted-move system "$fake_output_prefix.b" publication
wait_for "interrupted move request publication" move_request_present system
if timeout 2 "$AUDIOCTL" forget-bridge-target \
  "$durable_bridge_id" "$durable_bridge_serial" system \
  >"$work/concurrent-controller.log" 2>&1; then
  fail "a second controller entered an active same-channel transaction"
fi
grep -Fq "another output routing transaction is already active for channel 'system'" \
  "$work/concurrent-controller.log" \
  || fail "same-channel controller lock rejection was not actionable"
wait_for "first request preserved after concurrent controller rejection" \
  move_request_present system
kill -TERM "$paused_move_pid"
if wait "$paused_move_pid"; then
  interrupted_move_status=0
else
  interrupted_move_status=$?
fi
paused_move_pid=""
if ((interrupted_move_status != 143)); then
  fail "the interrupted controller exited with status $interrupted_move_status instead of 143"
fi
wait_for "interrupted durable move metadata cleanup" move_metadata_absent system
sleep 0.2
move_metadata_absent system \
  || fail "interrupted move published late control metadata after cleanup"
wait_for "System target after interrupted move" \
  bridge_target_is system "$fake_output_prefix.a"

start_paused_reset interrupted-reset system publication
wait_for "interrupted reset request publication" reset_request_present system
kill -TERM "$paused_move_pid"
if wait "$paused_move_pid"; then
  interrupted_reset_status=0
else
  interrupted_reset_status=$?
fi
paused_move_pid=""
if ((interrupted_reset_status != 143)); then
  fail "the interrupted reset exited with status $interrupted_reset_status instead of 143"
fi
wait_for "interrupted reset metadata cleanup" reset_metadata_absent system
sleep 0.2
reset_metadata_absent system \
  || fail "interrupted reset published late control metadata after cleanup"
wait_for "System target after interrupted reset" \
  bridge_target_is system "$fake_output_prefix.a"

start_paused_bridge_move \
  disappearing-target system "$fake_output_prefix.b" post-request-validation
wait_for "disappearing-target move request publication" move_request_present system
destroy_output b
: >"$paused_move_release"
if wait "$paused_move_pid"; then
  disappearing_target_status=0
else
  disappearing_target_status=$?
fi
paused_move_pid=""
if ((disappearing_target_status == 0)); then
  fail "the controller accepted a target removed during post-request validation"
fi
grep -Eq 'target node ID [0-9]+ is no longer live' "$work/disappearing-target.log" \
  || fail "target disappearance rejection was not actionable"
wait_for "disappearing-target durable move metadata cleanup" move_metadata_absent system
sleep 0.2
move_metadata_absent system \
  || fail "target disappearance published late control metadata after cleanup"
wait_for "System target after target disappearance" \
  bridge_target_is system "$fake_output_prefix.a"
create_output b
load_node_ref "$fake_output_prefix.b"
durable_target_id=$ref_id
durable_target_serial=$ref_serial

teardown_nonce="${durable_bridge_serial}:${BASHPID}:${RANDOM}:${RANDOM}"
pw-metadata -n default -- "$durable_bridge_id" \
  funforgiven.audio.move-output-target \
  "${teardown_nonce}:${durable_target_serial}" Spa:String >/dev/null
wait_for "bridge-teardown transaction arm" \
  move_ack_is "$durable_bridge_id" "${teardown_nonce}:armed"
printf 'destroy %s\n' "$durable_bridge_id" >&3
wait_for "armed bridge identity removal" \
  node_identity_absent "$durable_bridge_id" "$durable_bridge_serial"
wait_for "armed bridge transaction teardown" transaction_metadata_absent
sleep 0.2
transaction_metadata_absent \
  || fail "bridge teardown left late or orphaned transaction metadata"
stop_stack
start_stack
wait_for "System recovery after armed bridge teardown" \
  bridge_target_is system "$fake_output_prefix.a"
load_node_ref funforgiven.audio.channel.system.output
durable_bridge_id=$ref_id
durable_bridge_serial=$ref_serial
load_node_ref "$fake_output_prefix.b"
durable_target_id=$ref_id
durable_target_serial=$ref_serial

restart_wireplumber metadata-publish
wait_for "System target before normalized metadata fault" \
  bridge_target_is system "$fake_output_prefix.a"
if timeout 10 "$AUDIOCTL" move-bridge \
  "$durable_bridge_id" "$durable_bridge_serial" system \
  "$durable_target_id" "$durable_target_serial" \
  >"$work/fault-metadata-publish.log" 2>&1; then
  fail "the controller reported success after normalized target publication failed"
fi
grep -Fq 'durable state and the live target were rolled back' \
  "$work/fault-metadata-publish.log" \
  || fail "normalized target publication failure was not actionable"
wait_for "System rollback after normalized target publication failure" \
  bridge_target_is system "$fake_output_prefix.a"
wait_for "metadata publication fault transaction cleanup" move_metadata_absent system
restart_wireplumber final-ack-live-rollback
wait_for "System target before final acknowledgement fault" \
  bridge_target_is system "$fake_output_prefix.a"
if timeout 10 "$AUDIOCTL" move-bridge \
  "$durable_bridge_id" "$durable_bridge_serial" system \
  "$durable_target_id" "$durable_target_serial" \
  >"$work/fault-final-ack-live-rollback.log" 2>&1; then
  fail "the controller reported success after final acknowledgement publication failed"
fi
grep -Fq 'could not restore the live target metadata' \
  "$work/fault-final-ack-live-rollback.log" \
  || fail "incomplete live rollback failure was not actionable"
wait_for "unrestored live target metadata after injected rollback failure" \
  target_metadata_is "$durable_bridge_id" "$fake_output_prefix.b"
wait_for "final acknowledgement fault transaction cleanup" move_metadata_absent system
restart_wireplumber
wait_for "durable recovery after injected live rollback failure" \
  bridge_target_is system "$fake_output_prefix.a"

chmod -R a-w "$XDG_STATE_HOME"
if timeout 10 "$AUDIOCTL" move-bridge \
  "$durable_bridge_id" "$durable_bridge_serial" system \
  "$durable_target_id" "$durable_target_serial" \
  >"$work/unwritable-state-move.log" 2>&1; then
  unwritable_move_status=0
else
  unwritable_move_status=$?
fi
chmod -R u+w "$XDG_STATE_HOME"
if ((unwritable_move_status == 0)); then
  fail "the controller reported success for an output move that WirePlumber could not persist"
fi
grep -Fq 'could not durably persist' "$work/unwritable-state-move.log" \
  || fail "unwritable state rejection was not actionable"
wait_for "System rollback after durable state failure" \
  bridge_target_is system "$fake_output_prefix.a"
wait_for "durable move metadata cleanup after state failure" move_metadata_absent system

move_bridge system "$fake_output_prefix.b"
wait_for "System saved target before reset state failure" \
  bridge_target_is system "$fake_output_prefix.b"
chmod -R a-w "$XDG_STATE_HOME"
if timeout 10 "$AUDIOCTL" forget-bridge-target \
  "$durable_bridge_id" "$durable_bridge_serial" system \
  >"$work/unwritable-state-reset.log" 2>&1; then
  unwritable_reset_status=0
else
  unwritable_reset_status=$?
fi
chmod -R u+w "$XDG_STATE_HOME"
if ((unwritable_reset_status == 0)); then
  fail "the controller reported success for an output reset that WirePlumber could not persist"
fi
grep -Fq 'could not durably persist' "$work/unwritable-state-reset.log" \
  || fail "unwritable reset state rejection was not actionable"
wait_for "System rollback after reset state failure" \
  bridge_target_is system "$fake_output_prefix.b"
wait_for "reset metadata cleanup after state failure" reset_metadata_absent system
sleep 0.2
reset_metadata_absent system \
  || fail "reset state failure published late control metadata after cleanup"
move_bridge system "$fake_output_prefix.a"

stale_bridge_serial=0
if [[ $durable_bridge_serial == 0 ]]; then
  stale_bridge_serial=1
fi
stale_nonce="${stale_bridge_serial}:${BASHPID}:${RANDOM}:${RANDOM}"
pw-metadata -n default -- "$durable_bridge_id" \
  funforgiven.audio.move-output-target \
  "${stale_nonce}:${durable_target_serial}" Spa:String >/dev/null
wait_for "stale durable move identity rejection" \
  move_error_is "$durable_bridge_id" "${stale_nonce}:stale-identity"
clear_move_metadata "$durable_bridge_id"
wait_for "stale durable move metadata cleanup" move_metadata_absent system

superseded_nonce="${durable_bridge_serial}:${BASHPID}:${RANDOM}:${RANDOM}"
pw-metadata -n default -- "$durable_bridge_id" \
  funforgiven.audio.move-output-target \
  "${superseded_nonce}:${durable_target_serial}" Spa:String >/dev/null
wait_for "durable move request registration" \
  move_request_is "$durable_bridge_id" \
  "${superseded_nonce}:${durable_target_serial}"
wait_for "durable move request acknowledgement" \
  move_ack_is "$durable_bridge_id" "${superseded_nonce}:armed"
load_node_ref "$fake_output_prefix.a"
pw-metadata -n default -- "$durable_bridge_id" \
  target.object "$ref_serial" Spa:Id >/dev/null
wait_for "superseded durable move rejection" \
  move_error_is "$durable_bridge_id" "${superseded_nonce}:superseded"
wait_for "System rollback after superseded move" \
  bridge_target_is system "$fake_output_prefix.a"
clear_move_metadata "$durable_bridge_id"
wait_for "superseded durable move metadata cleanup" move_metadata_absent system

first_nonce="${durable_bridge_serial}:${BASHPID}:${RANDOM}:${RANDOM}"
first_request="${first_nonce}:${durable_target_serial}"
pw-metadata -n default -- "$durable_bridge_id" \
  funforgiven.audio.move-output-target "$first_request" Spa:String >/dev/null
wait_for "first overlapping durable move arm" \
  move_ack_is "$durable_bridge_id" "${first_nonce}:armed"
if timeout 10 "$AUDIOCTL" forget-bridge-target \
  "$durable_bridge_id" "$durable_bridge_serial" system \
  >"$work/reset-during-move.log" 2>&1; then
  fail "the policy accepted an output reset during a durable move"
fi
wait_for "first move request preserved after reset rejection" \
  move_request_is "$durable_bridge_id" "$first_request"
wait_for "first move arm preserved after reset rejection" \
  move_ack_is "$durable_bridge_id" "${first_nonce}:armed"
load_node_ref "$fake_output_prefix.a"
second_nonce="${durable_bridge_serial}:${BASHPID}:${RANDOM}:${RANDOM}"
pw-metadata -n default -- "$durable_bridge_id" \
  funforgiven.audio.move-output-target \
  "${second_nonce}:${ref_serial}" Spa:String >/dev/null
wait_for "overlapping durable move rejection" \
  move_error_is "$durable_bridge_id" "${second_nonce}:busy"
wait_for "first request preserved after overlapping move" \
  move_request_is "$durable_bridge_id" "$first_request"
wait_for "first arm preserved after overlapping move" \
  move_ack_is "$durable_bridge_id" "${first_nonce}:armed"
pw-metadata -n default -d -- "$durable_bridge_id" \
  funforgiven.audio.move-output-target-error >/dev/null
pw-metadata -n default -- "$durable_bridge_id" \
  target.object "$durable_target_serial" Spa:Id >/dev/null
wait_for "first overlapping durable move completion" \
  move_ack_is "$durable_bridge_id" "$first_nonce"
wait_for "first overlapping durable move target" \
  bridge_target_is system "$fake_output_prefix.b"
late_nonce="${durable_bridge_serial}:${BASHPID}:${RANDOM}:${RANDOM}"
load_node_ref "$fake_output_prefix.a"
pw-metadata -n default -- "$durable_bridge_id" \
  funforgiven.audio.move-output-target \
  "${late_nonce}:${ref_serial}" Spa:String >/dev/null
wait_for "post-ACK overlapping durable move rejection" \
  move_error_is "$durable_bridge_id" "${late_nonce}:busy"
wait_for "completed request preserved before release" \
  move_request_is "$durable_bridge_id" "$first_request"
wait_for "completed acknowledgement preserved before release" \
  move_ack_is "$durable_bridge_id" "$first_nonce"
pw-metadata -n default -d -- "$durable_bridge_id" \
  funforgiven.audio.move-output-target-error >/dev/null
pw-metadata -n default -d -- "$durable_bridge_id" \
  funforgiven.audio.move-output-target >/dev/null
pw-metadata -n default -d -- "$durable_bridge_id" \
  funforgiven.audio.move-output-target-ack >/dev/null
wait_for "overlapping durable move metadata cleanup" move_metadata_absent system

reset_nonce="${durable_bridge_serial}:${BASHPID}:${RANDOM}:${RANDOM}"
pw-metadata -n default -- "$durable_bridge_id" \
  funforgiven.audio.reset-output-target "$reset_nonce" Spa:String >/dev/null
wait_for "cross-locked reset request" \
  reset_metadata_is "$durable_bridge_id" \
  funforgiven.audio.reset-output-target "$reset_nonce"
wait_for "cross-locked reset arm" \
  reset_metadata_is "$durable_bridge_id" \
  funforgiven.audio.reset-output-target-ack "${reset_nonce}:armed"
load_node_ref "$fake_output_prefix.a"
if timeout 10 "$AUDIOCTL" move-bridge \
  "$durable_bridge_id" "$durable_bridge_serial" system "$ref_id" "$ref_serial" \
  >"$work/move-during-reset.log" 2>&1; then
  fail "the policy accepted a durable output move during a reset"
fi
wait_for "reset request preserved after durable move rejection" \
  reset_metadata_is "$durable_bridge_id" \
  funforgiven.audio.reset-output-target "$reset_nonce"
pw-metadata -n default -- "$durable_bridge_id" \
  funforgiven.audio.reset-output-target-commit "$reset_nonce" Spa:String >/dev/null
wait_for "cross-locked reset acknowledgement" \
  reset_metadata_is "$durable_bridge_id" \
  funforgiven.audio.reset-output-target-ack "$reset_nonce"
clear_reset_metadata "$durable_bridge_id"
wait_for "System neutral selection after cross-lock reset" \
  bridge_target_is system "$fake_output_prefix.a"
wait_for "cross-lock reset metadata cleanup" reset_metadata_absent system
run_graph_contract

load_node_ref funforgiven.audio.channel.system.output
disabled_bridge_id=$ref_id
disabled_bridge_serial=$ref_serial
load_node_ref "$fake_output_prefix.disabled"
if timeout 10 "$AUDIOCTL" move-bridge \
  "$disabled_bridge_id" "$disabled_bridge_serial" system "$ref_id" "$ref_serial" \
  >"$work/disabled-move.log" 2>&1; then
  fail "the controller accepted a disabled hardware output"
fi
grep -Fq 'disabled or unavailable' "$work/disabled-move.log" \
  || fail "disabled hardware output rejection was not actionable"

start_clients
wait_for "native default route" stream_linked_to "$native_app" system
wait_for "Pulse default route" stream_linked_to "$pulse_app" system

for application_id in "$native_app" "$pulse_app"; do
  for channel in "${channel_ids[@]}"; do
    move_stream "$application_id" "$channel"
  done
done

move_stream "$native_app" system
move_stream "$pulse_app" system
load_node_ref funforgiven.audio.channel.system.output
wpctl set-volume "$ref_id" 0.42
wpctl set-mute "$ref_id" 1
wait_for "aggregate System gain and mute" bridge_props_are system 0.074088 true
wait_for "native stream gain remains independent" stream_props_are_unity "$native_app"
wait_for "Pulse stream gain remains independent" stream_props_are_unity "$pulse_app"

move_stream "$native_app" music
move_stream "$pulse_app" voice
for channel in "${channel_ids[@]}"; do
  move_bridge "$channel" "$fake_output_prefix.b"
done
move_bridge game "$fake_output_prefix.a"
sleep 2
run_graph_contract

stop_clients
stop_stack
start_stack
wait_for "restored System output" bridge_target_is system "$fake_output_prefix.b"
wait_for "restored Game output" bridge_target_is game "$fake_output_prefix.a"
wait_for "restored Voice output" bridge_target_is voice "$fake_output_prefix.b"
wait_for "restored Music output" bridge_target_is music "$fake_output_prefix.b"
wait_for "restored aggregate System gain and mute" bridge_props_are system 0.074088 true
start_clients
wait_for "restored native app route" stream_linked_to "$native_app" music
wait_for "restored Pulse app route" stream_linked_to "$pulse_app" voice
run_graph_contract

destroy_output b
wait_for "System waiting for absent saved output" bridge_waiting_for system "$fake_output_prefix.b"
wait_for "Music waiting for absent saved output" bridge_waiting_for music "$fake_output_prefix.b"
create_output b
wait_for "System recovery after output return" bridge_target_is system "$fake_output_prefix.b"
wait_for "Music recovery after output return" bridge_target_is music "$fake_output_prefix.b"

load_node_ref funforgiven.audio.channel.system.output
bridge_id=$ref_id
bridge_serial=$ref_serial
unsafe_log="$work/unsafe-move.log"
: >"$unsafe_log"
for channel in "${channel_ids[@]}"; do
  for kind in "" .output; do
    target_name="funforgiven.audio.channel.$channel$kind"
    load_node_ref "$target_name"
    if timeout 10 "$AUDIOCTL" move-bridge \
      "$bridge_id" "$bridge_serial" system "$ref_id" "$ref_serial" \
      >"$work/unsafe-current.log" 2>&1; then
      fail "the controller accepted internal target $target_name"
    fi
    grep -Eq 'internal logical sink or bridge|cannot target itself' "$work/unsafe-current.log" \
      || fail "unsafe target rejection for $target_name was not actionable"
    printf 'target=%s\n' "$target_name" >>"$unsafe_log"
    cat "$work/unsafe-current.log" >>"$unsafe_log"
  done
done

move_bridge voice "$fake_output_prefix.a"
move_bridge voice "$fake_output_prefix.b"
forget_bridge_target voice
wait_for "Voice neutral selection after reset" bridge_target_is voice "$fake_output_prefix.a"
wait_for "Voice reset metadata cleanup" reset_metadata_absent voice
wait_for "System unchanged by Voice reset" bridge_target_is system "$fake_output_prefix.b"
wait_for "Game unchanged by Voice reset" bridge_target_is game "$fake_output_prefix.a"
wait_for "Music unchanged by Voice reset" bridge_target_is music "$fake_output_prefix.b"
sleep 2
wait_for "Voice reset survives deferred persistence" bridge_target_is voice "$fake_output_prefix.a"
stop_clients
stop_stack
start_stack
wait_for "persisted reset Voice output" bridge_target_is voice "$fake_output_prefix.a"
wait_for "persisted System output after Voice reset" bridge_target_is system "$fake_output_prefix.b"
wait_for "persisted Game output after Voice reset" bridge_target_is game "$fake_output_prefix.a"
wait_for "persisted Music output after Voice reset" bridge_target_is music "$fake_output_prefix.b"
start_clients
wait_for "native app route after Voice reset" stream_linked_to "$native_app" music
wait_for "Pulse app route after Voice reset" stream_linked_to "$pulse_app" voice
run_graph_contract
destroy_output a
wait_for "Voice waiting without fallback after reset" bridge_waiting_for voice "$fake_output_prefix.a"
wait_for "Game waiting for its saved output" bridge_waiting_for game "$fake_output_prefix.a"
wait_for "System remains on output B" bridge_target_is system "$fake_output_prefix.b"
wait_for "Music remains on output B" bridge_target_is music "$fake_output_prefix.b"
create_output a
wait_for "Voice recovery after reset target return" bridge_target_is voice "$fake_output_prefix.a"
wait_for "Game recovery after output return" bridge_target_is game "$fake_output_prefix.a"
run_graph_contract

find "$XDG_STATE_HOME" -type f -print -quit | grep -q . \
  || fail "WirePlumber did not persist any state"

# shellcheck disable=SC2154
mkdir -p "$out"
cp "$graph" "$out/final-graph.json"
cp "$work"/unsafe-move.log "$out/unsafe-move.log"
printf '%s\n' 'isolated four-channel audio integration test passed'
