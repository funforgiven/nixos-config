set -euo pipefail

readonly application_stop_timeout_seconds="${APPLICATION_STOP_TIMEOUT_SECONDS:-}"
readonly authorization_timeout_seconds="${AUTHORIZATION_TIMEOUT_SECONDS:-}"

if ! [[ "$application_stop_timeout_seconds" =~ ^[1-9][0-9]*$ ]]; then
  printf 'APPLICATION_STOP_TIMEOUT_SECONDS must be a positive integer\n' >&2
  exit 78
fi

if ! [[ "$authorization_timeout_seconds" =~ ^[1-9][0-9]*$ ]]; then
  printf 'AUTHORIZATION_TIMEOUT_SECONDS must be a positive integer\n' >&2
  exit 78
fi

usage() {
  printf 'usage: funforgiven-session-shutdown [--prepare] logout|reboot|poweroff\n' >&2
  exit 64
}

validate_action() {
  case "$1" in
    logout | reboot | poweroff) ;;
    *) usage ;;
  esac
}

require_graphical_session() {
  if ! systemctl --user --quiet is-active niri.service; then
    printf 'cannot exit the session: niri.service is not active\n' >&2
    exit 1
  fi

  if ! systemctl --user --quiet is-active graphical-session.target; then
    printf 'cannot exit the session: graphical-session.target is not active\n' >&2
    exit 1
  fi
}

stop_applications() {
  # app.slice owns both app2unit services and Niri-created transient scopes.
  # Keeping the compositor and session services in session.slice leaves the
  # display and user bus available while applications handle SIGTERM.
  local stop_status

  if timeout \
    --foreground \
    --signal=TERM \
    --kill-after=1s \
    "${application_stop_timeout_seconds}s" \
    systemctl --user --job-mode=replace-irreversibly stop app.slice; then
    return
  else
    stop_status=$?
  fi

  case "$stop_status" in
    124 | 137)
      printf \
        'application shutdown exceeded %ss; killing remaining app.slice processes\n' \
        "$application_stop_timeout_seconds" >&2
      systemctl --user kill --kill-whom=all --signal=SIGKILL app.slice
      ;;
    *)
      printf 'failed to stop app.slice (status %s)\n' "$stop_status" >&2
      return "$stop_status"
      ;;
  esac

  if timeout \
    --foreground \
    --signal=TERM \
    --kill-after=1s \
    1s \
    systemctl --user --job-mode=replace-irreversibly stop app.slice; then
    return
  else
    stop_status=$?
  fi

  case "$stop_status" in
    124 | 137)
      printf 'app.slice did not settle after SIGKILL\n' >&2
      return 1
      ;;
    *)
      printf 'failed to settle app.slice after SIGKILL (status %s)\n' "$stop_status" >&2
      return "$stop_status"
      ;;
  esac
}

queue_graphical_session_shutdown() {
  # This is Niri's supported systemd teardown path. Its ordering stops units
  # after graphical-session.target before it stops Niri itself. Queueing the
  # target is enough here: applications are already gone, and the delay lock
  # can be released without waiting on a second set of service stop budgets.
  systemctl --user --no-block --job-mode=replace-irreversibly start niri-shutdown.target
}

stop_graphical_session() {
  # Logout has no pending machine transaction to own the final teardown, so
  # keep the coordinator alive until Niri's shutdown target completes.
  systemctl --user --job-mode=replace-irreversibly start niri-shutdown.target
}

machine_shutdown_is_pending() {
  local state

  if ! state="$(
    busctl --system --json=short get-property \
      org.freedesktop.login1 \
      /org/freedesktop/login1 \
      org.freedesktop.login1.Manager \
      PreparingForShutdown
  )"; then
    printf 'could not query login1 shutdown state after authorization timeout\n' >&2
    return 1
  fi

  jq -e '.type == "b" and .data == true' <<<"$state" >/dev/null
}

prepare_system_shutdown() {
  local action="$1"

  # Request and authorize the machine action while the login session and
  # polkit agent are still alive. Block inhibitors cannot veto an explicitly
  # confirmed action; the caller's bounded delay inhibitor still holds the
  # system transaction while applications receive their normal stop signals.
  local authorization_status

  if timeout \
    --foreground \
    --signal=TERM \
    --kill-after=1s \
    "${authorization_timeout_seconds}s" \
    systemctl --check-inhibitors=no "$action"; then
    :
  else
    authorization_status=$?
    case "$authorization_status" in
      124 | 137)
        if machine_shutdown_is_pending; then
          printf '%s was accepted as its client timed out; continuing session cleanup\n' "$action" >&2
        else
          printf 'timed out waiting for %s authorization\n' "$action" >&2
          return 1
        fi
        ;;
      *)
        printf 'failed to authorize %s (status %s)\n' "$action" "$authorization_status" >&2
        return "$authorization_status"
        ;;
    esac
  fi
  stop_applications
  queue_graphical_session_shutdown
}

if (( $# == 2 )) && [[ "$1" == "--prepare" ]]; then
  validate_action "$2"
  if [[ "$2" == "logout" ]]; then
    usage
  fi

  require_graphical_session
  prepare_system_shutdown "$2"
  exit 0
fi

if (( $# != 1 )); then
  usage
fi

readonly action="$1"
validate_action "$action"
require_graphical_session

if [[ "$action" == "logout" ]]; then
  stop_applications
  stop_graphical_session
  exit 0
fi

exec systemd-inhibit \
  --what=shutdown \
  --who=funforgiven-session-shutdown \
  --why='Gracefully stopping the graphical session' \
  --mode=delay \
  "$0" --prepare "$action"
