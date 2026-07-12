test -f "$shell_config/shell.qml"

scan_args=(
  --color never
  --line-number
  --multiline
  --with-filename
  --glob "*.js"
  --glob "*.qml"
  --glob "qmldir"
  --glob "!**/fixtures/**"
  --glob "!**/test/**"
  --glob "!**/testdata/**"
  --glob "!**/tests/**"
)

failed=0
reject() {
  local description=$1
  local pattern=$2
  local matches
  local status

  set +e
  matches="$(rg "${scan_args[@]}" -- "$pattern" "$shell_config" 2>&1)"
  status=$?
  set -e

  case $status in
    0)
      echo "Forbidden $description found in the generated funforgiven-shell config:" >&2
      echo "$matches" >&2
      failed=1
      ;;
    1)
      ;;
    *)
      echo "Static scan for $description failed:" >&2
      echo "$matches" >&2
      exit "$status"
      ;;
  esac
}

reject \
  "DMS import or reference" \
  '(?i)\b(dms[a-z0-9_.-]*|dank[._ -]*(bar|config|material[._ -]*shell|settings|socket)|niri-config-dms)\b'
reject \
  "QML persistence API" \
  '\b(PersistentProperties|FileView|JsonAdapter)\b'
reject \
  "expensive blur or shader effect" \
  '\b(ShaderEffect|ShaderEffectSource|MultiEffect|FastBlur|GaussianBlur|RecursiveBlur|MaskedBlur|DirectionalBlur|RadialBlur|ZoomBlur)\b|\blayer\.effect\b'
reject \
  "shell interpreter invocation" \
  "(?i)\b(bash|dash|sh|zsh)[[:space:]\"',]+-c\b"
reject \
  "configuration-generation command or mutable configuration path" \
  "(?i)\b(config\.kdl|home-manager[[:space:]\"',]+(build|switch)|load-config-file|niri-config|nixos-rebuild|write-files|write-flake)\b|\.config/(niri|quickshell)\b|\bnix[[:space:]\"',]+(build|eval|run)\b"
reject \
  "hardcoded PipeWire global ID" \
  "\b(node|stream|sink|source|bridge|target|subject)([._-](global|object))?[._-]?id\b[[:space:]]*(===?|!==?)[[:space:]]*[0-9]+\b|\b(nodeId|streamId|sinkId|sourceId|bridgeId|targetId|subjectId|globalId|objectId)\b[[:space:]]*[:=][[:space:]]*[1-9][0-9]*\b|\bpw-(metadata|cli|link|dump)\b[^]]{0,512}[[:space:]\"',][0-9]+([[:space:]\"',]|])"

ui_paths=(
  "$shell_config/components"
  "$shell_config/bar"
  "$shell_config/dock"
  "$shell_config/launcher"
  "$shell_config/mixer"
  "$shell_config/idle"
)
set +e
polling_matches="$(rg \
  --color never \
  --line-number \
  --multiline \
  --multiline-dotall \
  --glob '*.qml' \
  '\bTimer[[:space:]]*\{[^}]*\brepeat[[:space:]]*:[[:space:]]*true\b' \
  "${ui_paths[@]}" 2>&1)"
polling_status=$?
set -e
case $polling_status in
  0)
    echo "Forbidden repeating UI timer found in the generated funforgiven-shell config:" >&2
    echo "$polling_matches" >&2
    failed=1
    ;;
  1)
    ;;
  *)
    echo "Static scan for repeating UI timers failed:" >&2
    echo "$polling_matches" >&2
    exit "$polling_status"
    ;;
esac

if ((failed != 0)); then
  exit 1
fi
