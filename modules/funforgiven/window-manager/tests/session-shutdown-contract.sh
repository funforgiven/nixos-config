#!/usr/bin/env bash
set -euo pipefail

trace_command() {
    local argument

    printf '%s' "${0##*/}" >>"$SESSION_SHUTDOWN_TEST_TRACE"
    for argument in "$@"; do
        printf ' %q' "$argument" >>"$SESSION_SHUTDOWN_TEST_TRACE"
    done
    printf '\n' >>"$SESSION_SHUTDOWN_TEST_TRACE"
}

fake_systemctl() {
    local stop_count

    trace_command "$@"
    case "$*" in
        "--user --quiet is-active niri.service" \
        | "--user --quiet is-active graphical-session.target" \
        | "--user kill --kill-whom=all --signal=SIGKILL app.slice" \
        | "--user --no-block --job-mode=replace-irreversibly start niri-shutdown.target" \
        | "--user --job-mode=replace-irreversibly start niri-shutdown.target")
            return 0
            ;;
        "--check-inhibitors=no poweroff" | "--check-inhibitors=no reboot")
            if [[ ${SESSION_SHUTDOWN_TEST_MODE:-success} == action-timeout ]]; then
                sleep 2
            fi
            return "${SESSION_SHUTDOWN_TEST_ACTION_STATUS:-0}"
            ;;
        "--user --job-mode=replace-irreversibly stop app.slice")
            stop_count="$(<"$SESSION_SHUTDOWN_TEST_STOP_COUNT")"
            ((stop_count += 1))
            printf '%s\n' "$stop_count" >"$SESSION_SHUTDOWN_TEST_STOP_COUNT"
            if [[ ${SESSION_SHUTDOWN_TEST_MODE:-success} == timeout && $stop_count -eq 1 ]]; then
                sleep 2
            fi
            if [[ ${SESSION_SHUTDOWN_TEST_MODE:-success} == stop-error && $stop_count -eq 1 ]]; then
                return 42
            fi
            return 0
            ;;
        *)
            printf 'unexpected systemctl argv: %s\n' "$*" >&2
            return 70
            ;;
    esac
}

fake_systemd_inhibit() {
    trace_command "$@"
    while (( $# > 0 )) && [[ $1 == --* ]]; do
        shift
    done
    (( $# > 0 )) || return 64
    exec bash "$@"
}

fake_busctl() {
    trace_command "$@"
    if [[ $* != "--system --json=short get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager PreparingForShutdown" ]]; then
        printf 'unexpected busctl argv: %s\n' "$*" >&2
        return 70
    fi
    printf '{"type":"b","data":%s}\n' "${SESSION_SHUTDOWN_TEST_PREPARING:-false}"
}

fake_jq() {
    local input

    trace_command "$@"
    IFS= read -r input
    [[ $input == '{"type":"b","data":true}' ]]
}

case "${0##*/}" in
    systemctl)
        fake_systemctl "$@"
        exit
        ;;
    systemd-inhibit)
        fake_systemd_inhibit "$@"
        exit
        ;;
    busctl)
        fake_busctl "$@"
        exit
        ;;
    jq)
        fake_jq "$@"
        exit
        ;;
esac

if (( $# != 1 )); then
    printf 'usage: session-shutdown-contract.sh SESSION_SHUTDOWN_HELPER\n' >&2
    exit 64
fi

readonly helper=$1
workdir="$(mktemp -d)"
readonly workdir
readonly fake_bin="$workdir/bin"
trap 'rm -rf "$workdir"' EXIT
mkdir -p "$fake_bin"
bash_executable="$(command -v bash)"
readonly bash_executable
{
    printf '#!%s\n' "$bash_executable"
    tail -n +2 "$0"
} >"$fake_bin/systemctl"
chmod 0755 "$fake_bin/systemctl"
ln -s systemctl "$fake_bin/systemd-inhibit"
ln -s systemctl "$fake_bin/busctl"
ln -s systemctl "$fake_bin/jq"

run_case() {
    local name=$1
    local mode=$2
    local action=$3
    local expected_status=$4
    local action_status=${5:-0}
    local preparing=${6:-false}
    local case_dir="$workdir/$name"
    local status

    mkdir -p "$case_dir"
    : >"$case_dir/trace"
    printf '0\n' >"$case_dir/stop-count"

    set +e
    PATH="$fake_bin:$PATH" \
        APPLICATION_STOP_TIMEOUT_SECONDS=1 \
        AUTHORIZATION_TIMEOUT_SECONDS=1 \
        SESSION_SHUTDOWN_TEST_ACTION_STATUS="$action_status" \
        SESSION_SHUTDOWN_TEST_MODE="$mode" \
        SESSION_SHUTDOWN_TEST_PREPARING="$preparing" \
        SESSION_SHUTDOWN_TEST_STOP_COUNT="$case_dir/stop-count" \
        SESSION_SHUTDOWN_TEST_TRACE="$case_dir/trace" \
        bash "$helper" "$action"
    status=$?
    set -e

    if (( status != expected_status )); then
        printf '%s: expected status %s, got %s\n' "$name" "$expected_status" "$status" >&2
        return 1
    fi
}

line_number() {
    local trace=$1
    local pattern=$2
    local line number=0

    while IFS= read -r line; do
        ((number += 1))
        if [[ $line == *"$pattern"* ]]; then
            printf '%s\n' "$number"
            return
        fi
    done <"$trace"
    printf 'missing trace pattern: %s\n' "$pattern" >&2
    return 1
}

assert_absent() {
    local trace=$1
    local pattern=$2

    if grep -Fq -- "$pattern" "$trace"; then
        printf 'unexpected trace pattern: %s\n' "$pattern" >&2
        return 1
    fi
}

run_case poweroff success poweroff 0
power_trace="$workdir/poweroff/trace"
power_action_line="$(line_number "$power_trace" 'systemctl --check-inhibitors=no poweroff')"
power_stop_line="$(line_number "$power_trace" 'systemctl --user --job-mode=replace-irreversibly stop app.slice')"
power_graphical_line="$(line_number "$power_trace" 'systemctl --user --no-block --job-mode=replace-irreversibly start niri-shutdown.target')"
((power_action_line < power_stop_line && power_stop_line < power_graphical_line))
grep -Fq 'systemd-inhibit --what=shutdown' "$power_trace"

run_case logout success logout 0
logout_trace="$workdir/logout/trace"
logout_stop_line="$(line_number "$logout_trace" 'systemctl --user --job-mode=replace-irreversibly stop app.slice')"
logout_graphical_line="$(line_number "$logout_trace" 'systemctl --user --job-mode=replace-irreversibly start niri-shutdown.target')"
((logout_stop_line < logout_graphical_line))
assert_absent "$logout_trace" '--check-inhibitors'
assert_absent "$logout_trace" '--no-block'
assert_absent "$logout_trace" 'systemd-inhibit'

run_case timeout timeout logout 0
timeout_trace="$workdir/timeout/trace"
test "$(grep -Fc 'systemctl --user --job-mode=replace-irreversibly stop app.slice' "$timeout_trace")" -eq 2
timeout_kill_line="$(line_number "$timeout_trace" 'systemctl --user kill --kill-whom=all --signal=SIGKILL app.slice')"
timeout_graphical_line="$(line_number "$timeout_trace" 'systemctl --user --job-mode=replace-irreversibly start niri-shutdown.target')"
((timeout_kill_line < timeout_graphical_line))

run_case stop-error stop-error logout 42
stop_error_trace="$workdir/stop-error/trace"
assert_absent "$stop_error_trace" '--signal=SIGKILL'
assert_absent "$stop_error_trace" 'niri-shutdown.target'

run_case action-error success poweroff 5 5
action_error_trace="$workdir/action-error/trace"
assert_absent "$action_error_trace" 'stop app.slice'
assert_absent "$action_error_trace" 'niri-shutdown.target'

run_case action-timeout action-timeout poweroff 1
action_timeout_trace="$workdir/action-timeout/trace"
assert_absent "$action_timeout_trace" 'stop app.slice'
assert_absent "$action_timeout_trace" 'niri-shutdown.target'

run_case action-timeout-committed action-timeout poweroff 0 0 true
action_timeout_committed_trace="$workdir/action-timeout-committed/trace"
grep -Fq 'busctl --system --json=short get-property' "$action_timeout_committed_trace"
grep -Fq 'systemctl --user --job-mode=replace-irreversibly stop app.slice' "$action_timeout_committed_trace"
grep -Fq 'systemctl --user --no-block --job-mode=replace-irreversibly start niri-shutdown.target' "$action_timeout_committed_trace"
