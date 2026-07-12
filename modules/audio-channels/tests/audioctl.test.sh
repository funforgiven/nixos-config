#!/usr/bin/env bash

set -euo pipefail

: "${AUDIOCTL_SOURCE:?AUDIOCTL_SOURCE is required}"

readonly test_tmp=${TMPDIR:-/tmp}

source "$AUDIOCTL_SOURCE"

fixture() {
  local route=$1
  local enum_route=$2

  jq -nc --argjson route "$route" --argjson enum_route "$enum_route" '
    [
      {
        id: 20,
        type: "PipeWire:Interface:Node",
        info: {
          props: {
            "object.serial": 220,
            "node.name": "test-output",
            "media.class": "Audio/Sink",
            "device.id": 30,
            "card.profile.device": 0
          }
        }
      },
      {
        id: 30,
        type: "PipeWire:Interface:Device",
        info: {
          props: { "device.name": "test-device" },
          params: { Route: $route, EnumRoute: $enum_route }
        }
      }
    ]
  '
}

load_fixture() {
  graph_json=$(fixture "$1" "$2")
  node_json=$(jq -c '.[] | select(.id == 20)' <<<"$graph_json")
}

expect_available() {
  load_fixture "$1" "$2"
  target_has_available_routes 30
}

expect_unavailable() {
  load_fixture "$1" "$2"
  if target_has_available_routes 30; then
    printf '%s\n' "expected hardware route to be unavailable" >&2
    exit 1
  fi
}

expect_available \
  '[{"device":0,"available":"yes"}]' \
  '[{"devices":[0],"available":"no"}]'
expect_unavailable \
  '[{"device":0,"available":"no"}]' \
  '[{"devices":[0],"available":"yes"}]'
expect_unavailable \
  '[]' \
  '[{"devices":[0],"available":"no"}]'
expect_available \
  '[]' \
  '[{"devices":[0],"available":"no"},{"devices":[0],"available":"unknown"}]'
expect_available \
  '[]' \
  '[{"devices":[1],"available":"no"}]'

load_fixture '[]' '[{"devices":[0],"available":"no"}]'
if (validate_hardware_target 10 20 220) >"$test_tmp/audioctl-route.out" 2>&1; then
  printf '%s\n' "controller accepted a target without an available hardware route" >&2
  exit 1
fi
grep -Fq 'has no available hardware route' "$test_tmp/audioctl-route.out"

first_nonce="42:100:200:300"
second_nonce="42:101:201:301"
first_request="${first_nonce}:500"
second_request="${second_nonce}:501"
graph_json=$(jq -nc \
  --arg first_nonce "$first_nonce" \
  --arg second_nonce "$second_nonce" \
  --arg first_request "$first_request" '
  [
    {
      id: 60,
      type: "PipeWire:Interface:Metadata",
      props: { "metadata.name": "default" },
      metadata: [
        {
          subject: 10,
          key: "funforgiven.audio.move-output-target",
          type: "Spa:String",
          value: $first_request
        },
        {
          subject: 10,
          key: "funforgiven.audio.move-output-target-ack",
          type: "Spa:String",
          value: ($first_nonce + ":armed")
        },
        {
          subject: 10,
          key: "funforgiven.audio.move-output-target-error",
          type: "Spa:String",
          value: ($second_nonce + ":busy")
        }
      ]
    }
  ]
')
pw_metadata_calls="$test_tmp/audioctl-pw-metadata-calls"
: >"$pw_metadata_calls"
try_load_graph() {
  :
}
pw-metadata() {
  local key=${!#}
  printf '%s\n' "$*" >>"$pw_metadata_calls"
  graph_json=$(jq -c --arg key "$key" '
    map(
      if .type == "PipeWire:Interface:Metadata" then
        .metadata |= map(select(.key != $key))
      else
        .
      end
    )
  ' <<<"$graph_json")
}
clear_owned_move_control_metadata 10 "$second_nonce" "$second_request"
grep -Fq "funforgiven.audio.move-output-target-error" "$pw_metadata_calls"
if grep -Eq 'move-output-target($| )|move-output-target-ack' "$pw_metadata_calls"; then
  printf '%s\n' "busy move cleanup deleted another transaction's control metadata" >&2
  exit 1
fi
