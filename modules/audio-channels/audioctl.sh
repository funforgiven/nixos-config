#!/usr/bin/env bash

set -euo pipefail

readonly program_name="${0##*/}"
readonly max_global_id="4294967294"
readonly max_object_serial="18446744073709551615"
readonly move_request_key="funforgiven.audio.move-output-target"
readonly move_ack_key="funforgiven.audio.move-output-target-ack"
readonly move_error_key="funforgiven.audio.move-output-target-error"
readonly reset_request_key="funforgiven.audio.reset-output-target"
readonly reset_commit_key="funforgiven.audio.reset-output-target-commit"
readonly reset_ack_key="funforgiven.audio.reset-output-target-ack"
readonly reset_error_key="funforgiven.audio.reset-output-target-error"

graph_json=""
node_json=""
destination_serial=""
default_metadata_serial=""
hardware_target_name=""
transaction_cleanup_enabled=false
transaction_cleanup_kind=""
transaction_cleanup_subject=""
transaction_cleanup_nonce=""
transaction_cleanup_request=""
transaction_lock_fd=""

usage() {
  cat <<'EOF'
Usage:
  funforgiven-audioctl move-stream SOURCE_ID SOURCE_SERIAL CHANNEL_ID
  funforgiven-audioctl move-bridge BRIDGE_ID BRIDGE_SERIAL CHANNEL_ID TARGET_ID TARGET_SERIAL
  funforgiven-audioctl forget-bridge-target BRIDGE_ID BRIDGE_SERIAL CHANNEL_ID

CHANNEL_ID must be one of: system, game, voice, music.

The IDs and object.serial values must come from the current PipeWire graph.
The command validates them again immediately before changing target.object
metadata. It does not keep routing state of its own.
EOF
}

usage_error() {
  printf '%s: error: %s\n' "$program_name" "$1" >&2
  printf "Try '%s --help' for usage.\n" "$program_name" >&2
  exit 64
}

runtime_error() {
  printf '%s: error: %s\n' "$program_name" "$1" >&2
  exit 1
}

is_canonical_uint_at_most() {
  local value=$1
  local maximum=$2
  local value_length=${#value}
  local max_length=${#maximum}
  local index
  local value_digit
  local maximum_digit

  [[ $value =~ ^(0|[1-9][0-9]*)$ ]] || return 1

  if ((value_length > max_length)); then
    return 1
  fi

  if ((value_length == max_length)); then
    for ((index = 0; index < value_length; index++)); do
      value_digit=${value:index:1}
      maximum_digit=${maximum:index:1}

      if ((value_digit < maximum_digit)); then
        return 0
      fi
      if ((value_digit > maximum_digit)); then
        return 1
      fi
    done
  fi
}

is_global_id() {
  is_canonical_uint_at_most "$1" "$max_global_id"
}

is_object_serial() {
  is_canonical_uint_at_most "$1" "$max_object_serial"
}

validate_global_id_argument() {
  local label=$1
  local value=$2

  if ! is_global_id "$value"; then
    usage_error "$label must be a canonical PipeWire global ID (0-$max_global_id); got '$value'"
  fi
}

validate_serial_argument() {
  local label=$1
  local value=$2

  if ! is_object_serial "$value"; then
    usage_error "$label must be a canonical PipeWire object.serial (0-$max_object_serial); got '$value'"
  fi
}

looks_like_lua_number() {
  local value=$1
  local decimal_pattern='^[[:space:]]*[+-]?(([0-9]+([.][0-9]*)?)|([.][0-9]+))([eE][+-]?[0-9]+)?[[:space:]]*$'
  local hexadecimal_pattern='^[[:space:]]*[+-]?0[xX](([0-9a-fA-F]+([.][0-9a-fA-F]*)?)|([.][0-9a-fA-F]+))([pP][+-]?[0-9]+)?[[:space:]]*$'

  [[ $value =~ $decimal_pattern || $value =~ $hexadecimal_pattern ]]
}

validate_channel_argument() {
  case $1 in
    system | game | voice | music) ;;
    *) usage_error "CHANNEL_ID must be exactly one of system, game, voice, or music; got '$1'" ;;
  esac
}

require_commands() {
  local command_name

  for command_name in flock jq pw-dump pw-metadata; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      runtime_error "required command '$command_name' is not available in PATH"
    fi
  done
}

acquire_channel_transaction_lock() {
  local channel_id=$1
  local lock_dir
  local lock_path

  if [[ -z ${XDG_RUNTIME_DIR:-} || $XDG_RUNTIME_DIR != /* ]]; then
    runtime_error "XDG_RUNTIME_DIR must name an absolute per-user runtime directory"
  fi
  lock_dir="$XDG_RUNTIME_DIR/funforgiven-audioctl"
  if ! mkdir -p -- "$lock_dir" || ! chmod 0700 -- "$lock_dir"; then
    runtime_error "could not prepare the audio transaction lock directory '$lock_dir'"
  fi
  lock_path="$lock_dir/$channel_id.lock"
  if ! exec {transaction_lock_fd}>"$lock_path"; then
    runtime_error "could not open the audio transaction lock for channel '$channel_id'"
  fi
  if ! flock -n "$transaction_lock_fd"; then
    exec {transaction_lock_fd}>&-
    transaction_lock_fd=""
    runtime_error "another output routing transaction is already active for channel '$channel_id'; retry after it finishes"
  fi
}

release_channel_transaction_lock() {
  if [[ -n $transaction_lock_fd ]]; then
    exec {transaction_lock_fd}>&-
    transaction_lock_fd=""
  fi
}

load_graph() {
  local dump

  if ! dump=$(pw-dump); then
    runtime_error "pw-dump could not read the PipeWire graph; confirm that the user PipeWire service is running"
  fi

  if ! jq -e 'type == "array" and all(.[]; type == "object")' >/dev/null <<<"$dump"; then
    runtime_error "pw-dump returned malformed JSON instead of a PipeWire object array"
  fi

  graph_json=$dump
}

capture_default_metadata() {
  local matches
  local count
  local serial

  if ! matches=$(
    jq -c '
      [
        .[]
        | select(.type == "PipeWire:Interface:Metadata")
        | select(.props["metadata.name"] == "default")
      ]
    ' <<<"$graph_json"
  ); then
    runtime_error "could not inspect the default PipeWire metadata object"
  fi
  if ! count=$(jq -r 'length' <<<"$matches"); then
    runtime_error "could not count default PipeWire metadata objects"
  fi
  if [[ $count != 1 ]]; then
    runtime_error "expected exactly one live PipeWire metadata object named 'default', found $count"
  fi
  if ! serial=$(
    jq -r '
      .[0].props["object.serial"]
      | if type == "number" or type == "string" then tostring else "" end
    ' <<<"$matches"
  ); then
    runtime_error "could not read object.serial for the default PipeWire metadata object"
  fi
  if ! is_object_serial "$serial"; then
    runtime_error "the default PipeWire metadata object has no valid object.serial"
  fi

  default_metadata_serial=$serial
}

require_same_default_metadata() {
  local expected_serial=$1

  capture_default_metadata
  if [[ $default_metadata_serial != "$expected_serial" ]]; then
    runtime_error "the default PipeWire metadata object restarted during the action; refresh the mixer and retry"
  fi
}

expect_target_metadata() {
  local subject_id=$1
  local expected_type=$2
  local expected_value=$3

  if ! jq -e \
    --arg subject "$subject_id" \
    --arg expected_type "$expected_type" \
    --arg expected_value "$expected_value" '
      [
        .[]
        | select(.type == "PipeWire:Interface:Metadata")
        | select(.props["metadata.name"] == "default")
        | .metadata[]?
        | select((.subject | tostring) == $subject)
        | select(.key == "target.object")
      ]
      | length == 1
        and .[0].type == $expected_type
        and (.[0].value | tostring) == $expected_value
    ' >/dev/null <<<"$graph_json"; then
    runtime_error "default metadata did not confirm target.object=$expected_value ($expected_type) for subject $subject_id"
  fi
}

normalized_bridge_target_metadata_matches() {
  local subject_id=$1
  local expected_name=$2

  jq -e \
    --arg subject "$subject_id" \
    --arg expected_name "$expected_name" '
      [
        .[]
        | select(.type == "PipeWire:Interface:Metadata")
        | select(.props["metadata.name"] == "default")
        | .metadata[]?
        | select((.subject | tostring) == $subject)
        | select(.key == "target.object")
      ]
      | length == 1
        and .[0].type == "Spa:String"
        and (.[0].value | tostring) == $expected_name
    ' >/dev/null <<<"$graph_json"
}

expect_metadata_key_absent() {
  local subject_id=$1
  local key=$2
  local label=$3
  local status

  if jq -e --arg subject "$subject_id" --arg key "$key" '
    any(
      .[]
      | select(.type == "PipeWire:Interface:Metadata")
      | select(.props["metadata.name"] == "default")
      | .metadata[]?;
      (.subject | tostring) == $subject
      and .key == $key
    )
  ' >/dev/null <<<"$graph_json"; then
    runtime_error "default metadata still contains $label for bridge subject $subject_id"
  else
    status=$?
    if ((status != 1)); then
      runtime_error "could not inspect $label in default metadata for bridge subject $subject_id"
    fi
  fi
}

metadata_string_matches() {
  local subject_id=$1
  local key=$2
  local expected_value=$3

  jq -e \
    --arg subject "$subject_id" \
    --arg key "$key" \
    --arg expected_value "$expected_value" '
    [
      .[]
      | select(.type == "PipeWire:Interface:Metadata")
      | select(.props["metadata.name"] == "default")
      | .metadata[]?
      | select((.subject | tostring) == $subject)
      | select(.key == $key)
    ]
    | length == 1
      and .[0].type == "Spa:String"
      and .[0].value == $expected_value
  ' >/dev/null <<<"$graph_json"
}

metadata_key_present() {
  local subject_id=$1
  local key=$2

  jq -e --arg subject "$subject_id" --arg key "$key" '
    any(
      .[]
      | select(.type == "PipeWire:Interface:Metadata")
      | select(.props["metadata.name"] == "default")
      | .metadata[]?;
      (.subject | tostring) == $subject and .key == $key
    )
  ' >/dev/null <<<"$graph_json"
}

reset_ack_matches() {
  metadata_string_matches "$1" "$reset_ack_key" "$2"
}

move_error_code() {
  local subject_id=$1
  local nonce=$2

  jq -er \
    --arg subject "$subject_id" \
    --arg key "$move_error_key" \
    --arg prefix "$nonce:" '
    [
      .[]
      | select(.type == "PipeWire:Interface:Metadata")
      | select(.props["metadata.name"] == "default")
      | .metadata[]?
      | select((.subject | tostring) == $subject)
      | select(.key == $key and .type == "Spa:String")
      | (.value | tostring)
      | select(startswith($prefix))
      | ltrimstr($prefix)
    ]
    | if length == 0 then ""
      elif length == 1 then .[0]
      else error("ambiguous durable move error metadata")
      end
  ' <<<"$graph_json"
}

reset_error_code() {
  local subject_id=$1
  local nonce=$2

  jq -er \
    --arg subject "$subject_id" \
    --arg key "$reset_error_key" \
    --arg prefix "$nonce:" '
    [
      .[]
      | select(.type == "PipeWire:Interface:Metadata")
      | select(.props["metadata.name"] == "default")
      | .metadata[]?
      | select((.subject | tostring) == $subject)
      | select(.key == $key and .type == "Spa:String")
      | (.value | tostring)
      | select(startswith($prefix))
      | ltrimstr($prefix)
    ]
    | if length == 0 then ""
      elif length == 1 then .[0]
      else error("ambiguous durable reset error metadata")
      end
  ' <<<"$graph_json"
}

try_load_graph() {
  local dump

  dump=$(pw-dump 2>/dev/null) || return 1
  jq -e 'type == "array" and all(.[]; type == "object")' \
    >/dev/null <<<"$dump" || return 1
  graph_json=$dump
}

owned_move_controls_absent() {
  local subject_id=$1
  local nonce=$2
  local request=$3

  jq -e \
    --arg subject "$subject_id" \
    --arg nonce "$nonce" \
    --arg request "$request" \
    --arg request_key "$move_request_key" \
    --arg ack_key "$move_ack_key" \
    --arg error_key "$move_error_key" '
    [
      .[]
      | select(.type == "PipeWire:Interface:Metadata")
      | select(.props["metadata.name"] == "default")
      | .metadata[]?
      | select((.subject | tostring) == $subject)
      | select(
          (.key == $request_key and .type == "Spa:String" and .value == $request)
          or (
            .key == $ack_key
            and .type == "Spa:String"
            and (.value == $nonce or .value == ($nonce + ":armed"))
          )
          or (
            .key == $error_key
            and .type == "Spa:String"
            and (.value | tostring | startswith($nonce + ":"))
          )
        )
    ] | length == 0
  ' >/dev/null <<<"$graph_json"
}

try_clear_owned_move_control_metadata() {
  local subject_id=$1
  local nonce=$2
  local request=$3
  local ack_owned
  local error_code
  local error_owned
  local expect_owned_request=false
  local _cleanup_attempt
  local request_owned

  for _cleanup_attempt in {1..20}; do
    if ! try_load_graph; then
      sleep 0.02
      continue
    fi

    request_owned=false
    ack_owned=false
    error_owned=false
    error_code=""
    if metadata_string_matches "$subject_id" "$move_request_key" "$request"; then
      request_owned=true
    fi
    if metadata_string_matches "$subject_id" "$move_ack_key" "$nonce" \
      || metadata_string_matches "$subject_id" "$move_ack_key" "$nonce:armed"; then
      ack_owned=true
    fi
    if ! error_code=$(move_error_code "$subject_id" "$nonce"); then
      sleep 0.02
      continue
    fi
    if [[ -n $error_code ]]; then
      error_owned=true
    fi

    if [[ $request_owned == true ]]; then
      expect_owned_request=false
      pw-metadata -n default -d -- "$subject_id" "$move_request_key" \
        >/dev/null 2>&1 || true
    elif metadata_key_present "$subject_id" "$move_request_key" \
      && { [[ $ack_owned == true ]] \
        || { [[ $error_owned == true && $error_code != busy ]]; } \
        || [[ $expect_owned_request == true ]]; }; then
      expect_owned_request=true
    fi
    if [[ $ack_owned == true ]]; then
      pw-metadata -n default -d -- "$subject_id" "$move_ack_key" \
        >/dev/null 2>&1 || true
    fi
    if [[ $error_owned == true ]]; then
      pw-metadata -n default -d -- "$subject_id" "$move_error_key" \
        >/dev/null 2>&1 || true
    fi

    sleep 0.02
    if try_load_graph && owned_move_controls_absent \
      "$subject_id" "$nonce" "$request"; then
      if [[ $expect_owned_request == true ]] \
        && metadata_key_present "$subject_id" "$move_request_key"; then
        continue
      fi
      return 0
    fi
  done
  return 1
}

owned_reset_controls_absent() {
  local subject_id=$1
  local nonce=$2

  jq -e \
    --arg subject "$subject_id" \
    --arg nonce "$nonce" \
    --arg request_key "$reset_request_key" \
    --arg commit_key "$reset_commit_key" \
    --arg ack_key "$reset_ack_key" \
    --arg error_key "$reset_error_key" '
    [
      .[]
      | select(.type == "PipeWire:Interface:Metadata")
      | select(.props["metadata.name"] == "default")
      | .metadata[]?
      | select((.subject | tostring) == $subject)
      | select(
          (
            (.key == $request_key or .key == $commit_key)
            and .type == "Spa:String"
            and .value == $nonce
          )
          or (
            .key == $ack_key
            and .type == "Spa:String"
            and (.value == $nonce or .value == ($nonce + ":armed"))
          )
          or (
            .key == $error_key
            and .type == "Spa:String"
            and (.value | tostring | startswith($nonce + ":"))
          )
        )
    ] | length == 0
  ' >/dev/null <<<"$graph_json"
}

try_clear_owned_reset_control_metadata() {
  local subject_id=$1
  local nonce=$2
  local error_code
  local key
  local _cleanup_attempt

  for _cleanup_attempt in {1..20}; do
    if ! try_load_graph; then
      sleep 0.02
      continue
    fi

    for key in "$reset_request_key" "$reset_commit_key"; do
      if metadata_string_matches "$subject_id" "$key" "$nonce"; then
        pw-metadata -n default -d -- "$subject_id" "$key" \
          >/dev/null 2>&1 || true
      fi
    done
    if metadata_string_matches "$subject_id" "$reset_ack_key" "$nonce" \
      || metadata_string_matches "$subject_id" "$reset_ack_key" "$nonce:armed"; then
      pw-metadata -n default -d -- "$subject_id" "$reset_ack_key" \
        >/dev/null 2>&1 || true
    fi
    if error_code=$(reset_error_code "$subject_id" "$nonce") \
      && [[ -n $error_code ]]; then
      pw-metadata -n default -d -- "$subject_id" "$reset_error_key" \
        >/dev/null 2>&1 || true
    fi

    sleep 0.02
    if try_load_graph && owned_reset_controls_absent "$subject_id" "$nonce"; then
      return 0
    fi
  done
  return 1
}

clear_owned_move_control_metadata() {
  if ! try_clear_owned_move_control_metadata "$1" "$2" "$3"; then
    runtime_error "failed to clear durable output move controls owned by nonce $2"
  fi
}

clear_owned_reset_control_metadata() {
  if ! try_clear_owned_reset_control_metadata "$1" "$2"; then
    runtime_error "failed to clear durable output reset controls owned by nonce $2"
  fi
}

arm_transaction_cleanup() {
  transaction_cleanup_kind=$1
  transaction_cleanup_subject=$2
  transaction_cleanup_nonce=$3
  transaction_cleanup_request=$4
  transaction_cleanup_enabled=true
  trap 'transaction_cleanup_on_exit "$?"' EXIT
  trap 'transaction_cleanup_on_signal 130' INT
  trap 'transaction_cleanup_on_signal 143' TERM
}

arm_move_cleanup() {
  arm_transaction_cleanup move "$1" "$2" "$3"
}

arm_reset_cleanup() {
  arm_transaction_cleanup reset "$1" "$2" "$2"
}

disarm_transaction_cleanup() {
  transaction_cleanup_enabled=false
  transaction_cleanup_kind=""
  transaction_cleanup_subject=""
  transaction_cleanup_nonce=""
  transaction_cleanup_request=""
  trap - EXIT INT TERM
}

try_cleanup_armed_transaction() {
  case $transaction_cleanup_kind in
    move)
      try_clear_owned_move_control_metadata \
        "$transaction_cleanup_subject" \
        "$transaction_cleanup_nonce" \
        "$transaction_cleanup_request"
      ;;
    reset)
      try_clear_owned_reset_control_metadata \
        "$transaction_cleanup_subject" \
        "$transaction_cleanup_nonce"
      ;;
    *) return 1 ;;
  esac
}

transaction_cleanup_on_exit() {
  local status=$1

  trap - EXIT INT TERM
  if [[ $transaction_cleanup_enabled == true ]] \
    && ! try_cleanup_armed_transaction; then
    printf '%s: error: failed to clean interrupted %s transaction %s\n' \
      "$program_name" "$transaction_cleanup_kind" \
      "$transaction_cleanup_nonce" >&2
    if ((status == 0)); then
      status=1
    fi
  fi
  transaction_cleanup_enabled=false
  exit "$status"
}

transaction_cleanup_on_signal() {
  local status=$1

  trap - EXIT INT TERM
  if [[ $transaction_cleanup_enabled == true ]] \
    && ! try_cleanup_armed_transaction; then
    printf '%s: error: failed to clean interrupted %s transaction %s\n' \
      "$program_name" "$transaction_cleanup_kind" \
      "$transaction_cleanup_nonce" >&2
  fi
  transaction_cleanup_enabled=false
  exit "$status"
}

expect_owned_move_controls_absent() {
  local subject_id=$1
  local nonce=$2
  local request=$3
  local error_code

  if metadata_string_matches "$subject_id" "$move_request_key" "$request" \
    || metadata_string_matches "$subject_id" "$move_ack_key" "$nonce" \
    || metadata_string_matches "$subject_id" "$move_ack_key" "$nonce:armed"; then
    runtime_error "default metadata still contains control state owned by durable move $nonce"
  fi
  if ! error_code=$(move_error_code "$subject_id" "$nonce"); then
    runtime_error "could not inspect durable move control cleanup for bridge subject $subject_id"
  fi
  if [[ -n $error_code ]]; then
    runtime_error "default metadata still contains an error owned by durable move $nonce"
  fi
}

finish_owned_move_cleanup() {
  clear_owned_move_control_metadata "$1" "$2" "$3"
  load_graph
  expect_owned_move_controls_absent "$1" "$2" "$3"
  disarm_transaction_cleanup
}

expect_owned_reset_controls_absent() {
  if ! owned_reset_controls_absent "$1" "$2"; then
    runtime_error "default metadata still contains output reset state owned by nonce $2"
  fi
}

finish_owned_reset_cleanup() {
  clear_owned_reset_control_metadata "$1" "$2"
  load_graph
  expect_owned_reset_controls_absent "$1" "$2"
  disarm_transaction_cleanup
}

expect_move_controls_absent() {
  local subject_id=$1

  expect_metadata_key_absent \
    "$subject_id" "$move_request_key" "a durable output move request"
  expect_metadata_key_absent \
    "$subject_id" "$move_ack_key" "a durable output move acknowledgement"
  expect_metadata_key_absent \
    "$subject_id" "$move_error_key" "a durable output move error"
}

expect_reset_controls_absent() {
  local subject_id=$1

  expect_metadata_key_absent \
    "$subject_id" "$reset_request_key" "an output reset request"
  expect_metadata_key_absent \
    "$subject_id" "$reset_commit_key" "an output reset commit"
  expect_metadata_key_absent \
    "$subject_id" "$reset_ack_key" "an output reset acknowledgement"
  expect_metadata_key_absent \
    "$subject_id" "$reset_error_key" "an output reset error"
}

report_move_error() {
  local channel_id=$1
  local target_id=$2
  local move_error=$3

  case $move_error in
    state-save)
      runtime_error "WirePlumber could not durably persist the output move for channel '$channel_id'; the live target was rolled back"
      ;;
    metadata-publish | ack-publish)
      runtime_error "WirePlumber could not publish the completed output move for channel '$channel_id'; durable state and the live target were rolled back"
      ;;
    arm-publish)
      runtime_error "WirePlumber could not arm durable output persistence for channel '$channel_id'"
      ;;
    rollback-live)
      runtime_error "WirePlumber restored durable state after a failed output move for channel '$channel_id' but could not restore the live target metadata; refresh the mixer and inspect WirePlumber before retrying"
      ;;
    rollback-save)
      runtime_error "WirePlumber restored the live target after a failed output move for channel '$channel_id' but could not restore durable state; inspect the WirePlumber state directory before retrying"
      ;;
    rollback-incomplete)
      runtime_error "WirePlumber could not restore either live target metadata or durable state after a failed output move for channel '$channel_id'; inspect WirePlumber before retrying"
      ;;
    unsafe-target)
      runtime_error "WirePlumber rejected target node ID $target_id as unavailable or unsafe and restored the previous output"
      ;;
    invalid-target)
      runtime_error "WirePlumber rejected malformed target metadata for channel '$channel_id' and restored the previous output"
      ;;
    superseded | busy)
      runtime_error "the durable output move for channel '$channel_id' was superseded by another routing action"
      ;;
    stale-identity)
      runtime_error "the channel '$channel_id' bridge identity changed during the durable output move; refresh the mixer and retry"
      ;;
    *)
      runtime_error "WirePlumber rejected the durable output move for channel '$channel_id' with error '$move_error'"
      ;;
  esac
}

report_reset_error() {
  local channel_id=$1
  local reset_error=$2

  case $reset_error in
    state-save)
      runtime_error "WirePlumber could not durably persist the output reset for channel '$channel_id'; the previous target was restored"
      ;;
    arm-publish)
      runtime_error "WirePlumber could not arm the output reset for channel '$channel_id'"
      ;;
    metadata-publish | ack-publish)
      runtime_error "WirePlumber could not publish the completed output reset for channel '$channel_id'; durable state and the live target were rolled back"
      ;;
    rollback-live)
      runtime_error "WirePlumber restored durable state after a failed output reset for channel '$channel_id' but could not restore the live target metadata; refresh the mixer and inspect WirePlumber before retrying"
      ;;
    rollback-save)
      runtime_error "WirePlumber restored the live target after a failed output reset for channel '$channel_id' but could not restore durable state; inspect the WirePlumber state directory before retrying"
      ;;
    rollback-incomplete)
      runtime_error "WirePlumber could not restore either live target metadata or durable state after a failed output reset for channel '$channel_id'; inspect WirePlumber before retrying"
      ;;
    busy)
      runtime_error "the output reset for channel '$channel_id' was blocked by another routing action"
      ;;
    stale-identity)
      runtime_error "the channel '$channel_id' bridge identity changed during the output reset; refresh the mixer and retry"
      ;;
    invalid-commit)
      runtime_error "WirePlumber rejected the output reset commit for channel '$channel_id'"
      ;;
    *)
      runtime_error "WirePlumber rejected the output reset for channel '$channel_id' with error '$reset_error'"
      ;;
  esac
}

expect_live_node() {
  local label=$1
  local expected_id=$2
  local expected_serial=$3
  local count
  local actual_serial

  if ! count=$(
    jq -r --arg id "$expected_id" '
      [
        .[]
        | select(.type == "PipeWire:Interface:Node")
        | select((.id | tostring) == $id)
      ]
      | length
    ' <<<"$graph_json"
  ); then
    runtime_error "could not inspect $label node ID $expected_id in the pw-dump JSON"
  fi

  case $count in
    0)
      runtime_error "$label node ID $expected_id is no longer live; refresh the mixer and try again"
      ;;
    1) ;;
    *)
      runtime_error "PipeWire reported $count nodes with ID $expected_id; refusing an ambiguous $label"
      ;;
  esac

  if ! node_json=$(
    jq -c --arg id "$expected_id" '
      first(
        .[]
        | select(.type == "PipeWire:Interface:Node")
        | select((.id | tostring) == $id)
      )
    ' <<<"$graph_json"
  ); then
    runtime_error "could not decode $label node ID $expected_id from the pw-dump JSON"
  fi

  if ! actual_serial=$(
    jq -r '
      .info.props["object.serial"]
      | if type == "number" or type == "string" then tostring else "" end
    ' <<<"$node_json"
  ); then
    runtime_error "could not read object.serial for $label node ID $expected_id"
  fi

  if ! is_object_serial "$actual_serial"; then
    runtime_error "$label node ID $expected_id has no valid unsigned 64-bit object.serial in the PipeWire graph"
  fi

  if [[ $actual_serial != "$expected_serial" ]]; then
    runtime_error "$label node ID $expected_id is stale or was reused: expected object.serial $expected_serial, found $actual_serial"
  fi
}

validate_unique_name_resolution() {
  local label=$1
  local expected_id=$2
  local stable_name=$3
  local matches
  local count
  local resolved_id

  if ! matches=$(
    jq -c --arg name "$stable_name" '
      [
        .[]
        | select(.type == "PipeWire:Interface:Node")
        | select(
            .info.props["node.name"] == $name
            or .info.props["object.path"] == $name
          )
      ]
    ' <<<"$graph_json"
  ); then
    runtime_error "could not validate WirePlumber name/path resolution for $label node ID $expected_id"
  fi

  if ! count=$(jq -r 'length' <<<"$matches"); then
    runtime_error "could not count WirePlumber resolver matches for $label node ID $expected_id"
  fi
  if [[ $count != 1 ]]; then
    runtime_error "$label node.name '$stable_name' resolves to $count live nodes through node.name/object.path; refusing an ambiguous identity"
  fi

  if ! resolved_id=$(jq -r '.[0].id | tostring' <<<"$matches"); then
    runtime_error "could not read the unique WirePlumber resolver match for $label node ID $expected_id"
  fi
  if [[ $resolved_id != "$expected_id" ]]; then
    runtime_error "$label node.name '$stable_name' resolves to node ID $resolved_id instead of selected node ID $expected_id"
  fi
}

validate_source_stream() {
  local source_id=$1
  local source_serial=$2
  local media_class

  expect_live_node "source stream" "$source_id" "$source_serial"

  if ! media_class=$(jq -r '.info.props["media.class"] // ""' <<<"$node_json"); then
    runtime_error "could not read media.class for source stream node ID $source_id"
  fi

  if [[ $media_class != "Stream/Output/Audio" ]]; then
    runtime_error "source node ID $source_id is '$media_class', not a Stream/Output/Audio playback stream"
  fi

  if jq -e '
    .info.props
    | has("funforgiven.audio.channel") or has("funforgiven.audio.kind")
  ' >/dev/null <<<"$node_json"; then
    runtime_error "source node ID $source_id is an internal audio-channel node, not an application playback stream"
  fi
}

resolve_logical_sink() {
  local channel_id=$1
  local matches
  local count
  local sink_id
  local sink_name
  local expected_sink_name
  local media_class

  if ! matches=$(
    jq -c --arg channel "$channel_id" '
      [
        .[]
        | select(.type == "PipeWire:Interface:Node")
        | select(.info.props["funforgiven.audio.channel"] == $channel)
        | select(.info.props["funforgiven.audio.kind"] == "sink")
      ]
    ' <<<"$graph_json"
  ); then
    runtime_error "could not resolve the marked logical sink for channel '$channel_id'"
  fi

  if ! count=$(jq -r 'length' <<<"$matches"); then
    runtime_error "could not count marked logical sinks for channel '$channel_id'"
  fi

  case $count in
    0)
      runtime_error "the marked logical sink for channel '$channel_id' is not live"
      ;;
    1) ;;
    *)
      runtime_error "found $count marked logical sinks for channel '$channel_id'; refusing an ambiguous destination"
      ;;
  esac

  if ! node_json=$(jq -c '.[0]' <<<"$matches"); then
    runtime_error "could not decode the logical sink for channel '$channel_id'"
  fi

  if ! sink_id=$(jq -r '.id | tostring' <<<"$node_json"); then
    runtime_error "could not read the node ID of channel '$channel_id'"
  fi

  if ! is_global_id "$sink_id"; then
    runtime_error "the logical sink for channel '$channel_id' has no valid PipeWire node ID"
  fi

  if ! destination_serial=$(
    jq -r '
      .info.props["object.serial"]
      | if type == "number" or type == "string" then tostring else "" end
    ' <<<"$node_json"
  ); then
    runtime_error "could not read object.serial for channel '$channel_id'"
  fi

  if ! is_object_serial "$destination_serial"; then
    runtime_error "the logical sink for channel '$channel_id' has no valid unsigned object.serial"
  fi

  if ! media_class=$(jq -r '.info.props["media.class"] // ""' <<<"$node_json"); then
    runtime_error "could not read media.class for channel '$channel_id'"
  fi

  if [[ $media_class != "Audio/Sink" ]]; then
    runtime_error "the node marked as channel '$channel_id' sink is '$media_class', not Audio/Sink"
  fi

  if ! jq -e '
    .info.props["node.virtual"] as $virtual
    | $virtual == true or $virtual == "true" or $virtual == "yes"
      or $virtual == 1 or $virtual == "1"
  ' >/dev/null <<<"$node_json"; then
    runtime_error "the node marked as channel '$channel_id' sink is not virtual; refusing an unsafe destination"
  fi

  if ! sink_name=$(jq -r '.info.props["node.name"] // ""' <<<"$node_json"); then
    runtime_error "could not read node.name for channel '$channel_id'"
  fi

  if [[ -z $sink_name ]]; then
    runtime_error "the logical sink for channel '$channel_id' has no stable node.name"
  fi

  expected_sink_name=${expected_sink_names[$channel_id]-}
  if [[ -z $expected_sink_name || $sink_name != "$expected_sink_name" ]]; then
    runtime_error "the marked '$channel_id' sink has node.name '$sink_name', expected '$expected_sink_name'"
  fi
  validate_unique_name_resolution "channel '$channel_id' sink" "$sink_id" "$sink_name"
}

validate_bridge() {
  local bridge_id=$1
  local bridge_serial=$2
  local channel_id=$3
  local marked_channel
  local marked_kind
  local media_class
  local bridge_name
  local expected_bridge_name

  expect_live_node "bridge" "$bridge_id" "$bridge_serial"

  if ! marked_channel=$(jq -r '.info.props["funforgiven.audio.channel"] // ""' <<<"$node_json"); then
    runtime_error "could not read the channel marker for bridge node ID $bridge_id"
  fi

  if ! marked_kind=$(jq -r '.info.props["funforgiven.audio.kind"] // ""' <<<"$node_json"); then
    runtime_error "could not read the kind marker for bridge node ID $bridge_id"
  fi

  if [[ $marked_channel != "$channel_id" || $marked_kind != "bridge" ]]; then
    runtime_error "node ID $bridge_id is not the marked '$channel_id' bridge"
  fi

  if ! media_class=$(jq -r '.info.props["media.class"] // ""' <<<"$node_json"); then
    runtime_error "could not read media.class for bridge node ID $bridge_id"
  fi

  if [[ $media_class != "Stream/Output/Audio" ]]; then
    runtime_error "marked bridge node ID $bridge_id is '$media_class', not Stream/Output/Audio"
  fi

  if ! bridge_name=$(jq -r '.info.props["node.name"] // ""' <<<"$node_json"); then
    runtime_error "could not read node.name for bridge node ID $bridge_id"
  fi

  if [[ -z $bridge_name ]]; then
    runtime_error "marked bridge node ID $bridge_id has no stable node.name"
  fi

  expected_bridge_name=${expected_bridge_names[$channel_id]-}
  if [[ -z $expected_bridge_name || $bridge_name != "$expected_bridge_name" ]]; then
    runtime_error "the marked '$channel_id' bridge has node.name '$bridge_name', expected '$expected_bridge_name'"
  fi
  validate_unique_name_resolution "channel '$channel_id' bridge" "$bridge_id" "$bridge_name"
}

target_would_create_cycle() {
  local target_id=$1
  local bridge_id=$2

  jq -e --arg start "$target_id" --arg goal "$bridge_id" '
    def endpoint($link; $field; $property):
      $link.info[$field] // $link.info.props[$property];

    def canonical_global_id:
      if type == "number" then
        . >= 0 and . <= 4294967294 and floor == .
      elif type == "string" then
        test("^(0|[1-9][0-9]*)$")
        and (
          length < 10
          or (length == 10 and . <= "4294967294")
        )
      else
        false
      end;

    def live_global_id($node_ids):
      . as $id
      | ($id | canonical_global_id)
        and (($node_ids | index($id | tostring)) != null);

    def reaches($edges; $start; $goal):
      def visit($pending; $seen):
        if ($pending | length) == 0 then
          false
        else
          $pending[0] as $current
          | if $current == $goal then
              true
            elif ($seen | index($current)) != null then
              visit($pending[1:]; $seen)
            else
              [ $edges[] | select(.from == $current) | .to ] as $next
              | visit($pending[1:] + $next; $seen + [$current])
            end
        end;
      visit([$start]; []);

    [ .[] | select(.type == "PipeWire:Interface:Node") ] as $nodes
    | [ $nodes[] | .id | tostring ] as $node_ids
    | [ .[] | select(.type == "PipeWire:Interface:Link") ] as $links
    | if any($nodes[]; (.id | canonical_global_id | not))
      or (($node_ids | unique | length) != ($node_ids | length))
      or any(
        $links[];
        (endpoint(.; "output-node-id"; "link.output.node") | live_global_id($node_ids) | not)
        or (endpoint(.; "input-node-id"; "link.input.node") | live_global_id($node_ids) | not)
      ) then
        error("the PipeWire graph has malformed, stale, or ambiguous structured link endpoints")
      else
        [
          $links[]
          | {
              from: (endpoint(.; "output-node-id"; "link.output.node") | tostring),
              to: (endpoint(.; "input-node-id"; "link.input.node") | tostring)
            }
        ] as $link_edges
        | [
            .[] as $sink
            | select($sink.type == "PipeWire:Interface:Node")
            | select($sink.info.props["funforgiven.audio.kind"] == "sink")
            | .[] as $bridge
            | select($bridge.type == "PipeWire:Interface:Node")
            | select($bridge.info.props["funforgiven.audio.kind"] == "bridge")
            | select(
                $bridge.info.props["funforgiven.audio.channel"]
                == $sink.info.props["funforgiven.audio.channel"]
              )
            | { from: ($sink.id | tostring), to: ($bridge.id | tostring) }
          ] as $channel_edges
        | reaches($link_edges + $channel_edges; $start; $goal)
      end
  ' <<<"$graph_json"
}

target_has_available_routes() {
  local device_id=$1

  jq -e --arg device_id "$device_id" --argjson target "$node_json" '
    def canonical_route_device:
      if type == "number" then
        if . >= 0 and . <= 2147483647 and floor == . then tostring else null end
      elif type == "string" and test("^(0|[1-9][0-9]*)$") then
        if length < 10 or (length == 10 and . <= "2147483647") then . else null end
      else
        null
      end;

    def route_is_available:
      ((.available // "unknown") | tostring | ascii_downcase) != "no";

    ($target.info.props["card.profile.device"] // null | canonical_route_device) as $profile_device
    | if $profile_device == null then
        true
      else
        [
          .[]
          | select(.type == "PipeWire:Interface:Device")
          | select((.id | tostring) == $device_id)
        ] as $devices
        | if ($devices | length) != 1 then
            error("target device identity changed during route validation")
          else
            ($devices[0].info.params.Route // []) as $active_routes
            | ($devices[0].info.params.EnumRoute // []) as $enumerated_routes
            | if ($active_routes | type) != "array" or
                ($enumerated_routes | type) != "array" then
                error("target device route parameters are malformed")
              else
                [
                  $active_routes[]
                  | select((.device | canonical_route_device) == $profile_device)
                ] as $active_matches
                | if ($active_matches | length) > 0 then
                    ($active_matches[0] | route_is_available)
                  else
                    [
                      $enumerated_routes[]
                      | select(any(
                          (.devices // [])[];
                          (. | canonical_route_device) == $profile_device
                        ))
                    ] as $enumerated_matches
                    | ($enumerated_matches | length) == 0 or
                      any($enumerated_matches[]; route_is_available)
                  end
              end
          end
      end
  ' <<<"$graph_json" >/dev/null
}

validate_hardware_target() {
  local bridge_id=$1
  local target_id=$2
  local target_serial=$3
  local media_class
  local target_name
  local device_id
  local device_count
  local availability_status
  local cycle_status

  expect_live_node "target" "$target_id" "$target_serial"

  if [[ $target_id == "$bridge_id" ]]; then
    runtime_error "bridge node ID $bridge_id cannot target itself"
  fi

  if jq -e '
    .info.props
    | has("funforgiven.audio.channel") or has("funforgiven.audio.kind")
  ' >/dev/null <<<"$node_json"; then
    runtime_error "target node ID $target_id is an internal logical sink or bridge"
  fi

  if ! media_class=$(jq -r '.info.props["media.class"] // ""' <<<"$node_json"); then
    runtime_error "could not read media.class for target node ID $target_id"
  fi

  if [[ $media_class != "Audio/Sink" ]]; then
    runtime_error "target node ID $target_id is '$media_class', not a live Audio/Sink"
  fi

  if jq -e '
    def truthy:
      . == true or . == "true" or . == "yes" or . == 1 or . == "1";

    .info.props
    | (."node.disabled" | truthy) or (."device.disabled" | truthy)
  ' >/dev/null <<<"$node_json"; then
    runtime_error "target node ID $target_id is disabled or unavailable"
  fi

  if jq -e '.info.state == "error"' >/dev/null <<<"$node_json"; then
    runtime_error "target node ID $target_id is in the PipeWire error state"
  fi

  if jq -e '
    .info.props["node.virtual"] as $virtual
    | $virtual == true or $virtual == "true" or $virtual == "yes"
      or $virtual == 1 or $virtual == "1"
  ' >/dev/null <<<"$node_json"; then
    runtime_error "target node ID $target_id is virtual; choose a device-backed physical Audio/Sink"
  fi

  if jq -e '
    def truthy:
      . == true or . == "true" or . == "yes" or . == 1 or . == "1";

    .info.props as $props
    | ($props["wireplumber.is-virtual"] | truthy)
      or ($props["wireplumber.is-fallback"] | truthy)
      or ($props["bluez5.loopback"] | truthy)
      or ($props | has("node.link-group"))
      or ($props | has("filter.smart"))
      or ($props | has("filter.smart.name"))
      or ($props | has("filter.smart.target"))
      or ($props["factory.name"] == "support.null-audio-sink")
  ' >/dev/null <<<"$node_json"; then
    runtime_error "target node ID $target_id is a virtual, fallback, null, or filter endpoint"
  fi

  if ! target_name=$(jq -r '.info.props["node.name"] // ""' <<<"$node_json"); then
    runtime_error "could not read node.name for target node ID $target_id"
  fi

  if [[ -z $target_name ]]; then
    runtime_error "target node ID $target_id has no stable node.name and cannot be persisted safely"
  fi

  if looks_like_lua_number "$target_name"; then
    runtime_error "target node ID $target_id has numeric-looking node.name '$target_name', which WirePlumber would misread as an object serial"
  fi

  validate_unique_name_resolution "target" "$target_id" "$target_name"

  if [[ $target_name == funforgiven.audio.channel.* ]]; then
    runtime_error "target node ID $target_id uses the reserved internal channel name '$target_name'"
  fi

  if ! device_id=$(
    jq -r '
      .info.props["device.id"]
      | if type == "number" or type == "string" then tostring else "" end
    ' <<<"$node_json"
  ); then
    runtime_error "could not read device.id for target node ID $target_id"
  fi

  if ! is_global_id "$device_id"; then
    runtime_error "target node ID $target_id is not device-backed; choose a physical Audio/Sink"
  fi

  if ! device_count=$(
    jq -r --arg device_id "$device_id" '
      [
        .[]
        | select(.type == "PipeWire:Interface:Device")
        | select((.id | tostring) == $device_id)
      ]
      | length
    ' <<<"$graph_json"
  ); then
    runtime_error "could not verify device backing for target node ID $target_id"
  fi

  if [[ $device_count != 1 ]]; then
    runtime_error "target node ID $target_id references device ID $device_id, but exactly one live PipeWire device was not found"
  fi

  if target_has_available_routes "$device_id"; then
    :
  else
    availability_status=$?
    if ((availability_status == 1)); then
      runtime_error "target node ID $target_id has no available hardware route"
    fi
    runtime_error "could not validate hardware route availability for target node ID $target_id"
  fi

  if target_would_create_cycle "$target_id" "$bridge_id" >/dev/null; then
    runtime_error "target node ID $target_id would create an audio graph cycle back to bridge node ID $bridge_id"
  else
    cycle_status=$?
    if ((cycle_status != 1)); then
      runtime_error "could not prove that target node ID $target_id is cycle-safe from the structured PipeWire link graph"
    fi
  fi

  hardware_target_name=$target_name
}

validate_move_stream_snapshot() {
  local source_id=$1
  local source_serial=$2
  local channel_id=$3

  validate_source_stream "$source_id" "$source_serial"
  resolve_logical_sink "$channel_id"
}

validate_move_bridge_snapshot() {
  local bridge_id=$1
  local bridge_serial=$2
  local channel_id=$3
  local target_id=$4
  local target_serial=$5

  validate_bridge "$bridge_id" "$bridge_serial" "$channel_id"
  validate_hardware_target "$bridge_id" "$target_id" "$target_serial"
}

move_stream() {
  local source_id=$1
  local source_serial=$2
  local channel_id=$3
  local metadata_serial
  local requested_destination_serial

  load_graph
  validate_move_stream_snapshot "$source_id" "$source_serial" "$channel_id"

  load_graph
  validate_move_stream_snapshot "$source_id" "$source_serial" "$channel_id"
  capture_default_metadata
  metadata_serial=$default_metadata_serial
  requested_destination_serial=$destination_serial

  if ! pw-metadata -n default -- "$source_id" target.object "$requested_destination_serial" Spa:Id; then
    runtime_error "failed to move source node ID $source_id to channel '$channel_id' (sink object.serial $requested_destination_serial)"
  fi

  load_graph
  require_same_default_metadata "$metadata_serial"
  validate_source_stream "$source_id" "$source_serial"
  expect_target_metadata "$source_id" Spa:Id "$requested_destination_serial"
}

move_bridge() {
  local bridge_id=$1
  local bridge_serial=$2
  local channel_id=$3
  local target_id=$4
  local target_serial=$5
  local metadata_serial
  local move_acknowledged=false
  local move_armed=false
  local move_error=""
  local move_nonce
  local move_request
  local requested_target_name

  acquire_channel_transaction_lock "$channel_id"
  load_graph
  validate_move_bridge_snapshot "$bridge_id" "$bridge_serial" "$channel_id" "$target_id" "$target_serial"

  load_graph
  validate_move_bridge_snapshot "$bridge_id" "$bridge_serial" "$channel_id" "$target_id" "$target_serial"
  capture_default_metadata
  metadata_serial=$default_metadata_serial
  requested_target_name=$hardware_target_name
  expect_move_controls_absent "$bridge_id"

  move_nonce="${bridge_serial}:${BASHPID}:${RANDOM}:${RANDOM}"
  move_request="${move_nonce}:${target_serial}"
  arm_move_cleanup "$bridge_id" "$move_nonce" "$move_request"
  if ! pw-metadata -n default -- \
    "$bridge_id" "$move_request_key" "$move_request" Spa:String; then
    runtime_error "failed to arm the durable output move for channel '$channel_id' bridge node ID $bridge_id"
  fi

  load_graph
  require_same_default_metadata "$metadata_serial"
  validate_move_bridge_snapshot "$bridge_id" "$bridge_serial" "$channel_id" "$target_id" "$target_serial"

  for _attempt in {1..60}; do
    if ! move_error=$(move_error_code "$bridge_id" "$move_nonce"); then
      runtime_error "could not inspect the durable output move arm result for channel '$channel_id'"
    fi
    if [[ -n $move_error ]]; then
      break
    fi
    if metadata_string_matches "$bridge_id" "$move_request_key" "$move_request" \
      && metadata_string_matches "$bridge_id" "$move_ack_key" "$move_nonce:armed"; then
      move_armed=true
      break
    fi
    if metadata_key_present "$bridge_id" "$move_request_key" \
      && ! metadata_string_matches "$bridge_id" "$move_request_key" "$move_request"; then
      move_error=busy
      break
    fi
    sleep 0.05
    load_graph
    require_same_default_metadata "$metadata_serial"
    validate_move_bridge_snapshot "$bridge_id" "$bridge_serial" "$channel_id" "$target_id" "$target_serial"
  done

  if [[ -n $move_error ]]; then
    finish_owned_move_cleanup "$bridge_id" "$move_nonce" "$move_request"
    report_move_error "$channel_id" "$target_id" "$move_error"
  fi

  if [[ $move_armed != true ]]; then
    finish_owned_move_cleanup "$bridge_id" "$move_nonce" "$move_request"
    runtime_error "WirePlumber did not arm durable persistence of the output move for channel '$channel_id'"
  fi

  if ! pw-metadata -n default -- "$bridge_id" target.object "$target_serial" Spa:Id; then
    finish_owned_move_cleanup "$bridge_id" "$move_nonce" "$move_request"
    runtime_error "failed to move channel '$channel_id' bridge node ID $bridge_id to target node ID $target_id"
  fi

  for _attempt in {1..60}; do
    load_graph
    require_same_default_metadata "$metadata_serial"
    validate_bridge "$bridge_id" "$bridge_serial" "$channel_id"
    if ! move_error=$(move_error_code "$bridge_id" "$move_nonce"); then
      finish_owned_move_cleanup "$bridge_id" "$move_nonce" "$move_request"
      runtime_error "could not inspect the durable output move result for channel '$channel_id'"
    fi
    if [[ -n $move_error ]]; then
      break
    fi
    if metadata_string_matches "$bridge_id" "$move_ack_key" "$move_nonce"; then
      move_acknowledged=true
      break
    fi
    sleep 0.05
  done

  if [[ -n $move_error ]]; then
    finish_owned_move_cleanup "$bridge_id" "$move_nonce" "$move_request"
    report_move_error "$channel_id" "$target_id" "$move_error"
  fi

  if [[ $move_acknowledged != true ]]; then
    finish_owned_move_cleanup "$bridge_id" "$move_nonce" "$move_request"
    runtime_error "WirePlumber did not acknowledge durable persistence of the output move for channel '$channel_id'"
  fi

  load_graph
  require_same_default_metadata "$metadata_serial"
  validate_bridge "$bridge_id" "$bridge_serial" "$channel_id"
  if ! normalized_bridge_target_metadata_matches \
    "$bridge_id" "$requested_target_name"; then
    finish_owned_move_cleanup "$bridge_id" "$move_nonce" "$move_request"
    runtime_error "WirePlumber did not confirm the normalized durable target for bridge subject $bridge_id"
  fi

  finish_owned_move_cleanup "$bridge_id" "$move_nonce" "$move_request"
  require_same_default_metadata "$metadata_serial"
  release_channel_transaction_lock
}

forget_bridge_target() {
  local bridge_id=$1
  local bridge_serial=$2
  local channel_id=$3
  local metadata_serial
  local reset_acknowledged=false
  local reset_armed=false
  local reset_error=""
  local reset_nonce

  acquire_channel_transaction_lock "$channel_id"
  load_graph
  validate_bridge "$bridge_id" "$bridge_serial" "$channel_id"
  capture_default_metadata
  metadata_serial=$default_metadata_serial

  load_graph
  validate_bridge "$bridge_id" "$bridge_serial" "$channel_id"
  expect_reset_controls_absent "$bridge_id"

  reset_nonce="${bridge_serial}:${BASHPID}:${RANDOM}:${RANDOM}"
  arm_reset_cleanup "$bridge_id" "$reset_nonce"
  if ! pw-metadata -n default -- \
    "$bridge_id" "$reset_request_key" "$reset_nonce" Spa:String; then
    runtime_error "failed to arm the reset for channel '$channel_id' bridge node ID $bridge_id"
  fi

  for _attempt in {1..60}; do
    load_graph
    require_same_default_metadata "$metadata_serial"
    validate_bridge "$bridge_id" "$bridge_serial" "$channel_id"
    if ! reset_error=$(reset_error_code "$bridge_id" "$reset_nonce"); then
      runtime_error "could not inspect the output reset arm result for channel '$channel_id'"
    fi
    if [[ -n $reset_error ]]; then
      break
    fi
    if metadata_string_matches \
      "$bridge_id" "$reset_request_key" "$reset_nonce" \
      && reset_ack_matches "$bridge_id" "$reset_nonce:armed"; then
      reset_armed=true
      break
    fi
    if metadata_key_present "$bridge_id" "$reset_request_key" \
      && ! metadata_string_matches \
        "$bridge_id" "$reset_request_key" "$reset_nonce"; then
      reset_error=busy
      break
    fi
    sleep 0.05
  done

  if [[ -n $reset_error ]]; then
    finish_owned_reset_cleanup "$bridge_id" "$reset_nonce"
    report_reset_error "$channel_id" "$reset_error"
  fi
  if [[ $reset_armed != true ]]; then
    finish_owned_reset_cleanup "$bridge_id" "$reset_nonce"
    runtime_error "WirePlumber did not arm the output reset for channel '$channel_id'"
  fi

  if ! pw-metadata -n default -- \
    "$bridge_id" "$reset_commit_key" "$reset_nonce" Spa:String; then
    finish_owned_reset_cleanup "$bridge_id" "$reset_nonce"
    runtime_error "failed to commit the output reset for channel '$channel_id' bridge node ID $bridge_id"
  fi

  for _attempt in {1..60}; do
    load_graph
    require_same_default_metadata "$metadata_serial"
    validate_bridge "$bridge_id" "$bridge_serial" "$channel_id"
    if ! reset_error=$(reset_error_code "$bridge_id" "$reset_nonce"); then
      runtime_error "could not inspect the output reset result for channel '$channel_id'"
    fi
    if [[ -n $reset_error ]]; then
      break
    fi
    if reset_ack_matches "$bridge_id" "$reset_nonce"; then
      reset_acknowledged=true
      break
    fi
    sleep 0.05
  done

  if [[ -n $reset_error ]]; then
    finish_owned_reset_cleanup "$bridge_id" "$reset_nonce"
    report_reset_error "$channel_id" "$reset_error"
  fi
  if [[ $reset_acknowledged != true ]]; then
    finish_owned_reset_cleanup "$bridge_id" "$reset_nonce"
    runtime_error "WirePlumber did not acknowledge the output reset for channel '$channel_id'"
  fi

  finish_owned_reset_cleanup "$bridge_id" "$reset_nonce"
  require_same_default_metadata "$metadata_serial"
  release_channel_transaction_lock
}

main() {
  if (($# == 1)) && [[ $1 == "--help" ]]; then
    usage
    return 0
  fi

  if (($# == 0)); then
    usage_error "an action is required"
  fi

  case $1 in
    move-stream)
      (($# == 4)) || usage_error "move-stream requires SOURCE_ID SOURCE_SERIAL CHANNEL_ID"
      validate_global_id_argument "SOURCE_ID" "$2"
      validate_serial_argument "SOURCE_SERIAL" "$3"
      validate_channel_argument "$4"
      require_commands
      move_stream "$2" "$3" "$4"
      ;;
    move-bridge)
      (($# == 6)) || usage_error "move-bridge requires BRIDGE_ID BRIDGE_SERIAL CHANNEL_ID TARGET_ID TARGET_SERIAL"
      validate_global_id_argument "BRIDGE_ID" "$2"
      validate_serial_argument "BRIDGE_SERIAL" "$3"
      validate_channel_argument "$4"
      validate_global_id_argument "TARGET_ID" "$5"
      validate_serial_argument "TARGET_SERIAL" "$6"
      require_commands
      move_bridge "$2" "$3" "$4" "$5" "$6"
      ;;
    forget-bridge-target)
      (($# == 4)) || usage_error "forget-bridge-target requires BRIDGE_ID BRIDGE_SERIAL CHANNEL_ID"
      validate_global_id_argument "BRIDGE_ID" "$2"
      validate_serial_argument "BRIDGE_SERIAL" "$3"
      validate_channel_argument "$4"
      require_commands
      forget_bridge_target "$2" "$3" "$4"
      ;;
    --help)
      usage_error "--help does not accept additional arguments"
      ;;
    *)
      usage_error "unknown action '$1'; expected move-stream, move-bridge, or forget-bridge-target"
      ;;
  esac
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
