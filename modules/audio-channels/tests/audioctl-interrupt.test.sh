#!/usr/bin/env bash

set -euo pipefail

: "${AUDIOCTL_SOURCE:?AUDIOCTL_SOURCE is required}"
: "${AUDIOCTL_PAUSE_MARKER:?AUDIOCTL_PAUSE_MARKER is required}"
: "${AUDIOCTL_PAUSE_PHASE:?AUDIOCTL_PAUSE_PHASE is required}"
: "${AUDIOCTL_PAUSE_RELEASE:?AUDIOCTL_PAUSE_RELEASE is required}"

source "$AUDIOCTL_SOURCE"

load_graph_definition=$(declare -f load_graph)
eval "${load_graph_definition/#load_graph/original_load_graph}"
load_graph_count=0

pause_audioctl() {
  : >"$AUDIOCTL_PAUSE_MARKER"
  while [[ ! -e $AUDIOCTL_PAUSE_RELEASE ]]; do
    sleep 0.01
  done
}

load_graph() {
  load_graph_count=$((load_graph_count + 1))
  if [[ $AUDIOCTL_PAUSE_PHASE == post-request-validation ]] \
    && ((load_graph_count == 3)); then
    pause_audioctl
  fi
  original_load_graph
}

pw-metadata() {
  local argument
  local deleting=false
  local transaction_request=false

  for argument in "$@"; do
    if [[ $argument == -d ]]; then
      deleting=true
    elif [[ $argument == "$move_request_key" \
      || $argument == "$reset_request_key" ]]; then
      transaction_request=true
    fi
  done
  if ! command pw-metadata "$@"; then
    return 1
  fi
  if [[ $AUDIOCTL_PAUSE_PHASE == publication \
    && $deleting == false \
    && $transaction_request == true ]]; then
    pause_audioctl
  fi
  return 0
}

main "$@"
