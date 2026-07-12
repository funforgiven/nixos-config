# shellcheck shell=bash

process_root="${RUNTIME_VALIDATION_PROC_ROOT:-/proc}"

scan_polkit_processes() {
    local process_dir executable process_name canonical_process_name comm

    for process_dir in "$process_root"/[0-9]*; do
        [[ -d "$process_dir" && -O "$process_dir" ]] || continue

        if ! executable="$(readlink "$process_dir/exe" 2>/dev/null)"; then
            executable=""
            IFS= read -r -d '' executable <"$process_dir/cmdline" 2>/dev/null || true
        fi
        if [[ -z $executable ]]; then
            comm=""
            IFS= read -r comm <"$process_dir/comm" 2>/dev/null || true
            if [[ $comm == *polkit* || $comm == *policykit* ]]; then
                printf '%s\t%s\t%s\n' \
                    "${process_dir##*/}" "unreadable:$comm" "unreadable"
            fi
            continue
        fi

        process_name=${executable##*/}
        canonical_process_name=${process_name#.}
        canonical_process_name=${canonical_process_name%-wrapped}
        case "$canonical_process_name" in
            polkit-kde-authentication-agent-1 \
            | polkit-gnome-authentication-agent-1 \
            | lxqt-policykit-agent \
            | lxpolkit \
            | mate-polkit \
            | polkit-mate-authentication-agent-1 \
            | hyprpolkitagent \
            | deepin-polkit-agent \
            | ukui-polkit-agent)
                printf '%s\t%s\t%s\n' \
                    "${process_dir##*/}" "$canonical_process_name" "$executable"
                ;;
        esac
    done
}

scan_session_niri() {
    local socket_name=$1 socket_stem pid executable

    socket_name=${socket_name##*/}
    socket_stem=${socket_name%.sock}
    pid=${socket_stem##*.}
    [[ "$pid" =~ ^[1-9][0-9]*$ ]] || return 0

    executable="$(readlink "$process_root/$pid/exe" 2>/dev/null || true)"
    [[ -n "$executable" ]] || return 0
    printf '%s\t%s\n' "$pid" "$executable"
}

if [[ "${RUNTIME_VALIDATION_POLKIT_SCAN_ONLY:-false}" == true ]]; then
    scan_polkit_processes
    exit 0
fi

if [[ "${RUNTIME_VALIDATION_NIRI_SCAN_ONLY:-false}" == true ]]; then
    scan_session_niri "${RUNTIME_VALIDATION_NIRI_SOCKET:-}"
    exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
probe_timeout=8
probe_dir="$tmpdir/probes"
mkdir -p "$probe_dir"

record_probe() {
    local name=$1
    local ok=$2
    local error=$3
    local filename=${name//[^A-Za-z0-9_.-]/_}
    shift 3

    jq -n \
        --arg name "$name" \
        --argjson ok "$ok" \
        --arg error "$error" \
        --args \
        '{ name: $name, ok: $ok, command: $ARGS.positional, error: $error }' \
        -- "$@" \
        >"$probe_dir/$filename.json"
}

capture_text() {
    local name=$1
    local destination=$2
    local status error
    shift 2

    : >"$destination.error"
    if timeout --signal=TERM --kill-after=1s "$probe_timeout" \
        "$@" >"$destination" 2>"$destination.error"; then
        record_probe "$name" true "" "$@"
        return 0
    else
        status=$?
    fi

    error="$(tr '\n' ' ' <"$destination.error")"
    error=${error:0:4000}
    [[ -n $error ]] || error="command exited with status $status"
    record_probe "$name" false "$error" "$@"
    return 1
}

capture_json() {
    local name=$1
    local destination=$2
    local fallback=$3
    local status error
    shift 3

    : >"$destination.error"
    if timeout --signal=TERM --kill-after=1s "$probe_timeout" \
        "$@" >"$destination" 2>"$destination.error"; then
        if jq empty "$destination" 2>/dev/null; then
            record_probe "$name" true "" "$@"
            return 0
        fi
        error="command returned invalid JSON"
    else
        status=$?
        error="$(tr '\n' ' ' <"$destination.error")"
        error=${error:0:4000}
        [[ -n $error ]] || error="command exited with status $status"
    fi

    printf '%s\n' "$fallback" >"$destination"
    record_probe "$name" false "$error" "$@"
    return 1
}

capture_quickshell_runtime_errors() {
    local pid=$1
    local journal_json="$tmpdir/quickshell-journal.jsonl"
    local journal_error="$tmpdir/quickshell-journal.error"

    : >"$journal_error"
    if [[ ! "$pid" =~ ^[1-9][0-9]*$ ]]; then
        printf '%s\n' "quickshell.service has no valid MainPID" >"$journal_error"
    elif ! timeout --signal=TERM --kill-after=1s "$probe_timeout" \
            journalctl --user --boot=0 "_PID=$pid" --no-pager \
            --output=json --output-fields=MESSAGE \
            >"$journal_json" 2>"$journal_error"; then
        :
    else
        record_probe "quickshell-journal" true "" \
            journalctl --user --boot=0 "_PID=$pid" --output=json
        jq -s '
          [
            .[]
            | ((.MESSAGE // "") | if type == "array" then implode else tostring end
                | gsub("\u001b\\[[0-9;]*m"; ""))
            | select(test("Failed to load configuration|Invalid property assignment| is not a type|TypeError|ReferenceError|Binding loop detected|Cannot read property [^ ]+ of null|Cannot anchor to an item"))
          ] as $errors
          | {
              available: true,
              count: ($errors | length),
              messages: ($errors | unique | .[0:20]),
              error: ""
            }
        ' "$journal_json" >"$tmpdir/quickshell-runtime-errors.json"
        return
    fi

    record_probe "quickshell-journal" false \
        "$(tr '\n' ' ' <"$journal_error")" \
        journalctl --user --boot=0 "_PID=$pid" --output=json
        jq -n \
            --rawfile error "$journal_error" \
            '{ available: false, count: 0, messages: [], error: ($error | gsub("[[:space:]]+$"; "")) }' \
            >"$tmpdir/quickshell-runtime-errors.json"
}

unit_property() {
    local unit=$1
    local property=$2
    local destination="$tmpdir/unit-${unit//[^A-Za-z0-9_.-]/_}-${property}"

    if capture_text "unit:$unit:$property" "$destination" \
        systemctl --user show "$unit" --property="$property" --value; then
        cat "$destination"
    fi
}

niri_models_match() {
    jq -e -n \
        --slurpfile workspaces "$tmpdir/workspaces.json" \
        --slurpfile windows "$tmpdir/windows.json" \
        --slurpfile diagnostics "$tmpdir/diagnostics.json" '
        ([
          $workspaces[0][]?
          | {
              id,
              name: (if (.name // "") == "" then null else .name end),
              output: (.output // null),
              active: (.is_active == true),
              focused: (.is_focused == true),
              urgent: (.is_urgent == true)
            }
        ] | sort_by(.id | tostring)) as $externalWorkspaces
        | ([
          ($diagnostics[0].niri.workspaces // [])[]?
          | {
              id,
              name: (.name // null),
              output: (.output // null),
              active: (.active == true),
              focused: (.focused == true),
              urgent: (.urgent == true)
            }
        ] | sort_by(.id | tostring)) as $shellWorkspaces
        | ([
          $windows[0][]?
          | {
              id,
              appId: (.app_id // ""),
              workspaceId: (.workspace_id // null),
              focused: (.is_focused == true),
              urgent: (.is_urgent == true)
            }
        ] | sort_by(.id | tostring)) as $externalWindows
        | ([
          ($diagnostics[0].niri.windows // [])[]?
          | {
              id,
              appId: (.appId // ""),
              workspaceId: (.workspaceId // null),
              focused: (.focused == true),
              urgent: (.urgent == true)
            }
        ] | sort_by(.id | tostring)) as $shellWindows
        | $externalWorkspaces == $shellWorkspaces
          and $externalWindows == $shellWindows
    ' >/dev/null
}

audio_models_match() {
    jq -e -n \
        --slurpfile pipewire "$tmpdir/pipewire.json" \
        --slurpfile diagnostics "$tmpdir/diagnostics.json" '
        def property_is_true:
          ((. // "" | tostring
            | gsub("^[[:space:]]+|[[:space:]]+$"; "")
            | ascii_downcase)) as $value
          | $value == "true" or $value == "yes" or $value == "1";

        ([
          $pipewire[0][]?
          | select(.type == "PipeWire:Interface:Node")
          | select(.info.props["media.class"] == "Stream/Output/Audio")
          | select((.info.props["funforgiven.audio.kind"] // "") != "bridge")
          | select((.info.props["funforgiven.audio.kind"] // "") != "sink")
          | select((.info.props["stream.monitor"] | property_is_true) | not)
          | select((.info.props["node.monitor"] | property_is_true) | not)
          | select(((.info.props["node.name"] // "")
              | test("(^|[._-])monitor($|[._-])"; "i")) | not)
          | select(any(
              .info.props["application.id"],
              .info.props["application.name"],
              .info.props["application.process.binary"],
              .info.props["client.name"];
              . != null and ((. | tostring | gsub("^[[:space:]]+|[[:space:]]+$"; "")) | length) > 0
            ))
          | {
              id: (.id | tostring),
              serial: (.info.props["object.serial"] | tostring)
            }
        ] | sort_by(.id, .serial)) as $direct
        | ([
          ($diagnostics[0].audio.playbackStreams // [])[]?
          | { id: (.id | tostring), serial: (.serial | tostring) }
        ] | sort_by(.id, .serial)) as $shell
        | $direct == $shell
    ' >/dev/null
}

quickshell_state="$(unit_property quickshell.service ActiveState)"
quickshell_pid="$(unit_property quickshell.service MainPID)"
graphical_session_state="$(unit_property graphical-session.target ActiveState)"
swayidle_state="$(unit_property swayidle.service ActiveState)"
swaybg_state="$(unit_property swaybg.service ActiveState)"
document_portal_state="$(unit_property xdg-document-portal.service ActiveState)"
document_portal_load_state="$(unit_property xdg-document-portal.service LoadState)"
kde_polkit_state="$(unit_property niri-flake-polkit.service ActiveState)"
kde_polkit_pid="$(unit_property niri-flake-polkit.service MainPID)"
dms_state="$(unit_property dms.service ActiveState)"
dms_load_state="$(unit_property dms.service LoadState)"
mako_state="$(unit_property mako.service ActiveState)"
swaync_state="$(unit_property swaync.service ActiveState)"
fcitx_state="$(unit_property fcitx5-daemon.service ActiveState)"
fcitx_pid="$(unit_property fcitx5-daemon.service MainPID)"
fcitx_runtime_state="0"
fcitx_current_input_method=""
if capture_text "fcitx-state" "$tmpdir/fcitx-state" fcitx5-remote --check; then
    fcitx_runtime_state="$(tr -d '[:space:]' <"$tmpdir/fcitx-state")"
fi
if capture_text "fcitx-input-method" "$tmpdir/fcitx-input-method" fcitx5-remote --check -n; then
    fcitx_current_input_method="$(tr -d '\r\n' <"$tmpdir/fcitx-input-method")"
fi

wayland_display=""
niri_socket=""
has_dms_launch_prefix=false
has_qt_style_override=false
capture_text "systemd-user-environment" "$tmpdir/systemd-environment" \
    systemctl --user show-environment || true
while IFS='=' read -r name value; do
    case "$name" in
        WAYLAND_DISPLAY) wayland_display=$value ;;
        NIRI_SOCKET) niri_socket=$value ;;
        DMS_DEFAULT_LAUNCH_PREFIX) has_dms_launch_prefix=true ;;
        QT_STYLE_OVERRIDE) has_qt_style_override=true ;;
    esac
done <"$tmpdir/systemd-environment"

niri_command=(
    env
    "NIRI_SOCKET=$niri_socket"
    "WAYLAND_DISPLAY=$wayland_display"
    niri
)

quickshell_executable=""
if [[ "$quickshell_pid" =~ ^[1-9][0-9]*$ ]]; then
    if capture_text "quickshell-executable" "$tmpdir/quickshell-executable" \
        readlink "$process_root/$quickshell_pid/exe"; then
        quickshell_executable="$(tr -d '\r\n' <"$tmpdir/quickshell-executable")"
    fi
else
    record_probe "quickshell-executable" false \
        "quickshell.service has no valid MainPID" \
        readlink "$process_root/$quickshell_pid/exe"
fi

scan_polkit_processes >"$tmpdir/polkit-processes.tsv"
jq -Rn '
    [
      inputs
      | split("\t")
      | { pid: (.[0] | tonumber), name: .[1], executable: .[2] }
    ]
    | sort_by(.pid)
' <"$tmpdir/polkit-processes.tsv" >"$tmpdir/polkit-processes.json"

scan_session_niri "$niri_socket" >"$tmpdir/niri-processes.tsv"
jq -Rn '
    [
      inputs
      | split("\t")
      | { pid: (.[0] | tonumber), executable: .[1] }
    ]
    | sort_by(.pid)
' <"$tmpdir/niri-processes.tsv" >"$tmpdir/niri-processes.json"

jq -n \
    --arg quickshell "$quickshell_state" \
    --arg quickshellPid "$quickshell_pid" \
    --arg quickshellExecutable "$quickshell_executable" \
    --arg graphicalSession "$graphical_session_state" \
    --arg swayidle "$swayidle_state" \
    --arg swaybg "$swaybg_state" \
    --arg documentPortal "$document_portal_state" \
    --arg documentPortalLoadState "$document_portal_load_state" \
    --arg kdePolkit "$kde_polkit_state" \
    --arg kdePolkitPid "$kde_polkit_pid" \
    --arg dms "$dms_state" \
    --arg dmsLoadState "$dms_load_state" \
    --arg mako "$mako_state" \
    --arg swaync "$swaync_state" \
    --arg fcitx "$fcitx_state" \
    --arg fcitxPid "$fcitx_pid" \
    --arg fcitxRuntimeState "$fcitx_runtime_state" \
    --arg fcitxCurrentInputMethod "$fcitx_current_input_method" \
    --arg waylandDisplay "$wayland_display" \
    --arg niriSocket "$niri_socket" \
    --argjson hasDmsLaunchPrefix "$has_dms_launch_prefix" \
    --argjson hasQtStyleOverride "$has_qt_style_override" \
    '{
        quickshell: $quickshell,
        quickshellPid: ($quickshellPid | tonumber? // 0),
        quickshellExecutable: $quickshellExecutable,
        graphicalSession: $graphicalSession,
        swayidle: $swayidle,
        swaybg: $swaybg,
        documentPortal: $documentPortal,
        documentPortalLoadState: $documentPortalLoadState,
        kdePolkit: $kdePolkit,
        kdePolkitPid: ($kdePolkitPid | tonumber? // 0),
        dms: $dms,
        dmsLoadState: $dmsLoadState,
        mako: $mako,
        swaync: $swaync,
        fcitx: $fcitx,
        fcitxPid: ($fcitxPid | tonumber? // 0),
        fcitxRuntimeState: ($fcitxRuntimeState | tonumber? // 0),
        fcitxCurrentInputMethod: $fcitxCurrentInputMethod,
        waylandDisplay: $waylandDisplay,
        niriSocket: $niriSocket,
        hasDmsLaunchPrefix: $hasDmsLaunchPrefix,
        hasQtStyleOverride: $hasQtStyleOverride
    }' >"$tmpdir/services.json"

capture_quickshell_runtime_errors "$quickshell_pid"

capture_json "niri-outputs" "$tmpdir/outputs.json" '{}' \
    "${niri_command[@]}" msg --json outputs || true
capture_json "pipewire-initial" "$tmpdir/pipewire.json" '[]' pw-dump || true
capture_json "quickshell-instances" "$tmpdir/instances.json" '[]' qs list -a -j || true
niri_models_settled=false
audio_models_settled=false
if [[ "$quickshell_pid" =~ ^[1-9][0-9]*$ ]]; then
    for attempt in 1 2 3 4 5; do
        capture_json "pipewire-settle-$attempt" "$tmpdir/pipewire.json" '[]' pw-dump || true
        capture_json "niri-workspaces-$attempt" "$tmpdir/workspaces.json" '[]' \
            "${niri_command[@]}" msg --json workspaces || true
        capture_json "niri-windows-$attempt" "$tmpdir/windows.json" '[]' \
            "${niri_command[@]}" msg --json windows || true
        capture_json "niri-layouts-$attempt" "$tmpdir/layouts.json" '{}' \
            "${niri_command[@]}" msg --json keyboard-layouts || true
        capture_json "quickshell-diagnostics-$attempt" "$tmpdir/diagnostics.json" '{}' \
            qs ipc --pid "$quickshell_pid" call diagnostics snapshot || true
        if niri_models_match; then niri_models_settled=true; else niri_models_settled=false; fi
        if audio_models_match; then audio_models_settled=true; else audio_models_settled=false; fi
        if [[ "$niri_models_settled" == true && "$audio_models_settled" == true ]]; then
            break
        fi
        if [[ "$attempt" != 5 ]]; then
            sleep 0.5
        fi
    done
else
    printf '[]\n' >"$tmpdir/workspaces.json"
    printf '[]\n' >"$tmpdir/windows.json"
    printf '{}\n' >"$tmpdir/layouts.json"
    printf '{}\n' >"$tmpdir/diagnostics.json"
fi

capture_json "audio-graph-contract" "$tmpdir/audio-graph-contract.json" \
    '{"ok":false,"errors":["graph contract probe failed"],"channels":[]}' \
    node "$RUNTIME_VALIDATION_GRAPH_CHECK" --runtime \
    "$tmpdir/pipewire.json" "$RUNTIME_VALIDATION_EXPECTED" || true

jq -s 'sort_by(.name)' "$probe_dir"/*.json >"$tmpdir/probes.json"

jq -n \
    --slurpfile expected "$RUNTIME_VALIDATION_EXPECTED" \
    --slurpfile services "$tmpdir/services.json" \
    --slurpfile outputs "$tmpdir/outputs.json" \
    --slurpfile workspaces "$tmpdir/workspaces.json" \
    --slurpfile windows "$tmpdir/windows.json" \
    --slurpfile layouts "$tmpdir/layouts.json" \
    --slurpfile pipewire "$tmpdir/pipewire.json" \
    --slurpfile instances "$tmpdir/instances.json" \
    --slurpfile diagnostics "$tmpdir/diagnostics.json" \
    --slurpfile niriProcesses "$tmpdir/niri-processes.json" \
    --slurpfile polkitProcesses "$tmpdir/polkit-processes.json" \
    --slurpfile quickshellRuntimeErrors "$tmpdir/quickshell-runtime-errors.json" \
    --slurpfile audioGraphContract "$tmpdir/audio-graph-contract.json" \
    --slurpfile probes "$tmpdir/probes.json" \
    --argjson niriModelsSettled "$niri_models_settled" \
    --argjson audioModelsSettled "$audio_models_settled" '
    def property_is_true:
      ((. // "" | tostring
        | gsub("^[[:space:]]+|[[:space:]]+$"; "")
        | ascii_downcase)) as $value
      | $value == "true" or $value == "yes" or $value == "1";

    def check($name; $ok; $detail): {
        name: $name,
        ok: $ok,
        detail: $detail
    };

    $expected[0] as $expected
    | $services[0] as $services
    | $outputs[0] as $outputs
    | $workspaces[0] as $workspaces
    | $windows[0] as $windows
    | $layouts[0] as $layouts
    | $pipewire[0] as $pipewire
    | $instances[0] as $instances
    | $diagnostics[0] as $diagnostics
    | $niriProcesses[0] as $niriProcesses
    | $polkitProcesses[0] as $polkitProcesses
    | $quickshellRuntimeErrors[0] as $quickshellRuntimeErrors
    | $audioGraphContract[0] as $audioGraphContract
    | $probes[0] as $probes
    | ([
        $pipewire[]?
        | select(.info.props."funforgiven.audio.kind" == "sink")
        | .info.props."node.name"
      ] | sort) as $sinkNames
    | ([
        $pipewire[]?
        | select(.info.props."funforgiven.audio.kind" == "bridge")
        | .info.props."node.name"
      ] | sort) as $bridgeNames
    | ([
        $workspaces[]?
        | {
            id,
            name: (if (.name // "") == "" then null else .name end),
            output: (.output // null),
            active: (.is_active == true),
            focused: (.is_focused == true),
            urgent: (.is_urgent == true)
          }
      ] | sort_by(.id | tostring)) as $externalWorkspaces
    | ([
        ($diagnostics.niri.workspaces // [])[]?
        | {
            id,
            name: (.name // null),
            output: (.output // null),
            active: (.active == true),
            focused: (.focused == true),
            urgent: (.urgent == true)
          }
      ] | sort_by(.id | tostring)) as $shellWorkspaces
    | ([
        $windows[]?
        | {
            id,
            appId: (.app_id // ""),
            workspaceId: (.workspace_id // null),
            focused: (.is_focused == true),
            urgent: (.is_urgent == true)
          }
      ] | sort_by(.id | tostring)) as $externalWindows
    | ([
        ($diagnostics.niri.windows // [])[]?
        | {
            id,
            appId: (.appId // ""),
            workspaceId: (.workspaceId // null),
            focused: (.focused == true),
            urgent: (.urgent == true)
          }
      ] | sort_by(.id | tostring)) as $shellWindows
    | ($diagnostics.audio.channels // []) as $channels
    | ([
        $pipewire[]?
        | select(.type == "PipeWire:Interface:Node")
        | select(.info.props["media.class"] == "Stream/Output/Audio")
        | select((.info.props["funforgiven.audio.kind"] // "") != "bridge")
        | select((.info.props["funforgiven.audio.kind"] // "") != "sink")
        | select((.info.props["stream.monitor"] | property_is_true) | not)
        | select((.info.props["node.monitor"] | property_is_true) | not)
        | select(((.info.props["node.name"] // "")
            | test("(^|[._-])monitor($|[._-])"; "i")) | not)
        | select(any(
            .info.props["application.id"],
            .info.props["application.name"],
            .info.props["application.process.binary"],
            .info.props["client.name"];
            . != null and ((. | tostring | gsub("^[[:space:]]+|[[:space:]]+$"; "")) | length) > 0
          ))
        | { id: (.id | tostring), serial: (.info.props["object.serial"] | tostring) }
      ] | sort_by(.id, .serial)) as $directPlaybackRefs
    | ([
        ($diagnostics.audio.playbackStreams // [])[]?
        | { id: (.id | tostring), serial: (.serial | tostring) }
      ] | sort_by(.id, .serial)) as $shellPlaybackRefs
    | [
        check("graphical session target";
          $services.graphicalSession == "active";
          $services.graphicalSession),
        check("runtime probes succeeded";
          ($probes | length) > 0 and all($probes[]; .ok == true);
          {
            count: ($probes | length),
            failed: [ $probes[] | select(.ok != true) ]
          }),
        check("supervised shell service";
          $services.quickshell == "active" and $services.quickshellPid > 0;
          { state: $services.quickshell, pid: $services.quickshellPid }),
        check("current session runs the evaluated Quickshell";
          $services.quickshellExecutable == $expected.quickshellExecutable;
          {
            expected: $expected.quickshellExecutable,
            running: $services.quickshellExecutable
          }),
        check("current session runs the evaluated Niri";
          ($niriProcesses | length) == 1
            and $niriProcesses[0].executable == $expected.niriExecutable;
          { expected: $expected.niriExecutable, running: $niriProcesses }),
        check("exactly one Quickshell instance";
          ($instances | length) == 1
            and ($instances[0].pid // 0) == $services.quickshellPid;
          $instances),
        check("shell diagnostics endpoint";
          $diagnostics.configName == $expected.configName;
          ($diagnostics.configName // null)),
        check("current Quickshell process has no QML runtime errors";
          $quickshellRuntimeErrors.available == true
            and $quickshellRuntimeErrors.count == 0;
          $quickshellRuntimeErrors),
        check("session environment imported";
          ($services.waylandDisplay | length) > 0
            and ($services.niriSocket | length) > 0
            and $services.hasDmsLaunchPrefix == false
            and $services.hasQtStyleOverride == false;
          {
            waylandDisplay: $services.waylandDisplay,
            niriSocketPresent: (($services.niriSocket | length) > 0),
            hasDmsLaunchPrefix: $services.hasDmsLaunchPrefix,
            hasQtStyleOverride: $services.hasQtStyleOverride
          }),
        check("session-owned wallpaper and idle services";
          $services.swayidle == "active" and $services.swaybg == "active";
          { swayidle: $services.swayidle, swaybg: $services.swaybg }),
        check("single Fcitx Turkish/Japanese state";
          $services.fcitx == "active"
            and $services.fcitxPid > 0
            and (
              ($services.fcitxRuntimeState == 1
                and $services.fcitxCurrentInputMethod == "keyboard-tr")
              or ($services.fcitxRuntimeState == 2
                and $services.fcitxCurrentInputMethod == "mozc")
            );
          {
            unitState: $services.fcitx,
            pid: $services.fcitxPid,
            runtimeState: $services.fcitxRuntimeState,
            currentInputMethod: $services.fcitxCurrentInputMethod
          }),
        check("document portal is available";
          $services.documentPortalLoadState == "loaded"
            and $services.documentPortal != "failed";
          {
            state: $services.documentPortal,
            loadState: $services.documentPortalLoadState
          }),
        check("no notification daemon";
          $services.mako != "active" and $services.swaync != "active";
          { mako: $services.mako, swaync: $services.swaync }),
        check("no DMS runtime";
          $services.dms != "active"
            and $services.dmsLoadState == "not-found"
            and ($instances | length) == 1
            and all($windows[]?; ((.app_id // "") | ascii_downcase | contains("dms") | not))
            and all(($diagnostics.niri.windows // [])[]?; ((.appId // "") | ascii_downcase | contains("dms") | not));
          {
            unitState: $services.dms,
            unitLoadState: $services.dmsLoadState,
            niriAppIds: [$windows[]? | .app_id]
          }),
        check("exact configured outputs";
          (($outputs | keys | sort) == ($expected.outputs | sort));
          ($outputs | keys | sort)),
        check("one shell screen per configured output";
          (($diagnostics.screens // [] | sort) == ($expected.outputs | sort));
          ($diagnostics.screens // [] | sort)),
        check("authoritative Niri event state";
          $niriModelsSettled == true
            and $diagnostics.niri.connected == true
            and $diagnostics.niri.stale == false
            and ($diagnostics.niri.generation // 0) > 0;
          ($diagnostics.niri // {} | {
            connected,
            stale,
            generation,
            error,
            modelsSettled: $niriModelsSettled
          })),
        check("Niri workspace output ownership";
          ($workspaces | length) >= 4
            and all($workspaces[]?;
              .output != null
                and (.output as $output | ($expected.outputs | index($output)) != null))
            and ([ $workspaces[]? | select(.is_active == true) | .output ] | sort)
              == ($expected.outputs | sort)
            and ([ $workspaces[]? | select(.is_focused == true) ] | length) == 1
            and $shellWorkspaces == $externalWorkspaces;
          { direct: $externalWorkspaces, shell: $shellWorkspaces }),
        check("Niri window model follows event state";
          $shellWindows == $externalWindows;
          { direct: $externalWindows, shell: $shellWindows }),
        check("fixed Niri physical keyboard layout";
          ($layouts.names // []) == $expected.physicalKeyboardNames
            and ($layouts.current_idx // -1) == 0;
          {
            external: $layouts,
            expected: $expected.physicalKeyboardNames
          }),
        check("exact four logical sinks";
          $sinkNames == ($expected.channels | map(.sinkName) | sort);
          $sinkNames),
        check("exact four aggregate bridges";
          $bridgeNames == ($expected.channels | map(.bridgeName) | sort);
          $bridgeNames),
        check("shell audio graph ready";
          $diagnostics.audio.ready == true
            and ($channels | map(.id)) == ($expected.channels | map(.id))
            and all($channels[]?; .sinkPresent and .bridgePresent)
            and ([ $channels[]? | select(.observedDefault) | .id ]) == ["system"]
            and $diagnostics.audio.defaultWarning == false;
          {
            ready: ($diagnostics.audio.ready // false),
            observedDefault: ($diagnostics.audio.observedDefaultChannelId // ""),
            defaultWarning: $diagnostics.audio.defaultWarning,
            channels: $channels
          }),
        check("shell playback model matches PipeWire application nodes";
          $audioModelsSettled == true and $shellPlaybackRefs == $directPlaybackRefs;
          {
            modelsSettled: $audioModelsSettled,
            direct: $directPlaybackRefs,
            shell: ($diagnostics.audio.playbackStreams // [])
          }),
        check("all channel bridges have safe physical targets";
          $audioGraphContract.ok == true
            and ($audioGraphContract.channels | map(.id)) == ($expected.channels | map(.id))
            and ($channels | map(.id)) == ($expected.channels | map(.id))
            and all($audioGraphContract.channels[]?;
              . as $direct
              | ([ $channels[]? | select(.id == $direct.id) ]) as $matches
              | ($matches | length) == 1
                and $direct.sinkPresent == true
                and $direct.bridgePresent == true
                and $direct.targetConnected == true
                and $direct.targetPhysical == true
                and $direct.targetAvailable == true
                and $direct.targetCycleSafe == true
                and $matches[0].state == "connected"
                and $matches[0].outputName == $direct.targetName
                and $matches[0].outputPhysical == $direct.targetPhysical
                and $matches[0].outputAvailable == $direct.targetAvailable
                and $matches[0].outputCycleSafe == $direct.targetCycleSafe);
          {
            direct: $audioGraphContract,
            shell: [
              $channels[]?
              | { id, state, outputName, outputPhysical, outputAvailable, outputCycleSafe, message }
            ]
          }),
        check("audio action layer is idle and error-free";
          ($diagnostics.audio.pendingActionCount // -1) == 0
            and ($diagnostics.audio.recentErrors // -1) == 0
            and ($diagnostics.audio.unroutedGroupCount // -1) == 0;
          {
            pending: ($diagnostics.audio.pendingActionCount // null),
            recentErrors: ($diagnostics.audio.recentErrors // null),
            unroutedGroups: ($diagnostics.audio.unroutedGroupCount // null)
          }),
        check("selected polkit agent process";
          if $expected.polkitAgent == "kde" then
            $services.kdePolkit == "active"
              and $services.kdePolkitPid > 0
              and ($polkitProcesses | length) == 1
              and $polkitProcesses[0].name == $expected.kdePolkitProcess
              and $polkitProcesses[0].pid == $services.kdePolkitPid
              and $diagnostics.polkit.enabled == false
          else
            $services.kdePolkit != "active"
              and $services.kdePolkitPid == 0
              and ($polkitProcesses | length) == 0
              and $diagnostics.polkit.enabled == true
              and $diagnostics.polkit.loaded == true
              and $diagnostics.polkit.registered == true
          end;
          {
            expected: $expected.polkitAgent,
            kdeUnit: {
              state: $services.kdePolkit,
              pid: $services.kdePolkitPid
            },
            knownAgentProcesses: $polkitProcesses,
            native: ($diagnostics.polkit // null)
          })
      ] as $checks
    | {
        ok: all($checks[]; .ok),
        checkedAt: (now | todateiso8601),
        checks: $checks,
        failed: [ $checks[] | select(.ok | not) | .name ],
        observations: {
          amoledVisible: $diagnostics.amoledVisible,
          mixerVisible: $diagnostics.mixerVisible,
          physicalOutputCount: ($diagnostics.audio.physicalOutputCount // null),
          windowCount: ($windows | length)
        }
      }
    ' >"$tmpdir/result.json"

cat "$tmpdir/result.json"
jq -e '.ok' "$tmpdir/result.json" >/dev/null
