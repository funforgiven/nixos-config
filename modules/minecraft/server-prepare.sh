set -euo pipefail

readonly program_name="${0##*/}"

die() {
  printf '%s: %s\n' "$program_name" "$*" >&2
  exit 1
}

set_setting() {
  local file="$1"
  local key="$2"
  local value="$3"
  local missing_policy="$4"
  local temporary_file
  local line
  local matches=0

  temporary_file="$(mktemp "${file}.managed.XXXXXX")"

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"

    if [[ "$line" == "${key}="* ]]; then
      printf '%s=%s\n' "$key" "$value" >>"$temporary_file"
      matches="$((matches + 1))"
    else
      printf '%s\n' "$line" >>"$temporary_file"
    fi
  done <"$file"

  if [[ "$matches" -gt 1 ]]; then
    rm -f -- "$temporary_file"
    die "expected at most one '${key}=' entry in ${file}, found ${matches}"
  fi

  if [[ "$matches" -eq 0 ]]; then
    if [[ "$missing_policy" != "append" ]]; then
      rm -f -- "$temporary_file"
      die "required '${key}=' entry is missing from ${file}"
    fi

    printf '%s=%s\n' "$key" "$value" >>"$temporary_file"
  fi

  chmod --reference="$file" "$temporary_file"
  mv -fT -- "$temporary_file" "$file"
}

set_fml_max_threads() {
  local target_directory="$1"
  local config_directory="${target_directory}/config"
  local config_file="${config_directory}/fml.toml"
  local temporary_file
  local line
  local matches=0

  [[ -d "$config_directory" && ! -L "$config_directory" ]] ||
    die "the server pack is missing a regular config directory"
  if [[ -e "$config_file" ]]; then
    [[ -f "$config_file" && ! -L "$config_file" ]] ||
      die "refusing to manage non-regular ${config_file}"
  fi

  temporary_file="$(mktemp "${config_directory}/.fml.toml.managed.XXXXXX")"

  if [[ -f "$config_file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%$'\r'}"

      if [[ "$line" =~ ^[[:space:]]*maxThreads[[:space:]]*= ]]; then
        printf 'maxThreads = %s\n' "$fml_max_threads" >>"$temporary_file"
        matches="$((matches + 1))"
      else
        printf '%s\n' "$line" >>"$temporary_file"
      fi
    done <"$config_file"
  fi

  if [[ "$matches" -gt 1 ]]; then
    rm -f -- "$temporary_file"
    die "expected at most one 'maxThreads' entry in ${config_file}, found ${matches}"
  fi

  if [[ "$matches" -eq 0 ]]; then
    {
      printf '\n'
      printf '# Serialize early mod initialization to avoid the Exosphere %s Mixin/LibJF deadlock.\n' "$pack_version"
      printf 'maxThreads = %s\n' "$fml_max_threads"
    } >>"$temporary_file"
  fi

  if [[ -f "$config_file" ]]; then
    chmod --reference="$config_file" "$temporary_file"
  else
    chmod 0640 "$temporary_file"
  fi
  mv -fT -- "$temporary_file" "$config_file"
}

write_eula() {
  local target_directory="$1"
  local eula_accepted="$2"
  local temporary_file

  [[ "$eula_accepted" == "true" ]] ||
    die "refusing to start without explicit Minecraft EULA acceptance"

  temporary_file="$(mktemp "${target_directory}/.eula.txt.XXXXXX")"
  {
    printf '# Managed from the explicit EULA acceptance in the NixOS configuration.\n'
    printf 'eula=true\n'
  } >"$temporary_file"
  chmod 0640 "$temporary_file"
  mv -fT -- "$temporary_file" "${target_directory}/eula.txt"
}

configure_server() {
  local target_directory="$1"
  local variables_file="${target_directory}/variables.txt"
  local properties_file="${target_directory}/server.properties"

  [[ -f "${target_directory}/start.sh" && ! -L "${target_directory}/start.sh" ]] ||
    die "the server pack is missing a regular start.sh"
  [[ -f "$variables_file" && ! -L "$variables_file" ]] ||
    die "the server pack is missing a regular variables.txt"
  [[ -f "$properties_file" && ! -L "$properties_file" ]] ||
    die "the server pack is missing a regular server.properties"

  # systemd owns lifecycle and supplies the exact Java runtime.
  set_setting "$variables_file" "WAIT_FOR_USER_INPUT" "false" "required"
  set_setting "$variables_file" "JAVA" "\"${java_executable}\"" "required"
  set_setting "$variables_file" "JAVA_ARGS" "\"${java_arguments}\"" "required"
  set_setting "$variables_file" "RESTART" "false" "required"
  set_setting "$variables_file" "SKIP_JAVA_CHECK" "false" "required"
  set_setting "$variables_file" "SERVERSTARTERJAR_FORCE_FETCH" "false" "required"

  # Keep the pack's remaining gameplay settings mutable, but own the exposed
  # network surface. Online-mode authenticates players without restricting
  # access to a separately managed allowlist.
  set_setting "$properties_file" "server-ip" "" "append"
  set_setting "$properties_file" "server-port" "$server_port" "append"
  set_setting "$properties_file" "online-mode" "true" "append"
  set_setting "$properties_file" "enable-query" "false" "append"
  set_setting "$properties_file" "enable-rcon" "false" "append"
  set_setting "$properties_file" "white-list" "false" "append"
  set_setting "$properties_file" "enforce-whitelist" "false" "append"

  set_fml_max_threads "$target_directory"
  write_eula "$target_directory" "$eula_accepted"
}

if [[ "$#" -ne 10 ]]; then
  die "internal error: expected state directory, URL, checksum, version, archive root, EULA acceptance, Java, Java arguments, port, and FML thread limit"
fi

readonly state_directory="$1"
readonly download_url="$2"
readonly expected_sha256="$3"
readonly pack_version="$4"
readonly archive_root="$5"
readonly eula_accepted="$6"
readonly java_executable="$7"
readonly java_arguments="$8"
readonly server_port="$9"
readonly fml_max_threads="${10}"
readonly server_directory="${state_directory}/server"
readonly version_marker="${server_directory}/.nix-managed-pack-version"

[[ "$fml_max_threads" =~ ^[1-9][0-9]*$ ]] ||
  die "FML thread limit must be a positive integer, got '${fml_max_threads}'"

if [[ -L "$server_directory" ]]; then
  die "refusing to use symlinked server directory ${server_directory}"
fi

if [[ -d "$server_directory" ]]; then
  [[ -f "$version_marker" && ! -L "$version_marker" ]] ||
    die "existing server directory has no trusted version marker; refusing to overwrite it"

  installed_version="$(<"$version_marker")"
  if [[ "$installed_version" != "$pack_version" ]]; then
    die "found pack ${installed_version}, expected ${pack_version}; back up the world and migrate the pack manually"
  fi

  configure_server "$server_directory"
  exit 0
fi

bootstrap_directory="$(mktemp -d "${state_directory}/.bootstrap.XXXXXX")"
readonly bootstrap_directory
cleanup() {
  rm -rf -- "$bootstrap_directory"
}
trap cleanup EXIT

readonly archive="${bootstrap_directory}/server-pack.zip"
readonly archive_listing="${bootstrap_directory}/archive-listing.txt"
readonly checksum_file="${bootstrap_directory}/server-pack.sha256"
readonly unpacked_directory="${bootstrap_directory}/unpacked"

printf 'Downloading Exosphere 2 + Create server pack %s (about 412 MiB)...\n' "$pack_version"
curl \
  --connect-timeout 30 \
  --fail \
  --location \
  --no-progress-meter \
  --proto '=https' \
  --proto-redir '=https' \
  --retry 3 \
  --retry-all-errors \
  --show-error \
  --tlsv1.2 \
  --output "$archive" \
  "$download_url"

printf '%s  %s\n' "$expected_sha256" "$archive" >"$checksum_file"
if ! sha256sum --check --status "$checksum_file"; then
  die "server pack checksum mismatch; expected ${expected_sha256}"
fi

unzip -Z1 "$archive" >"$archive_listing"
while IFS= read -r entry; do
  if
    [[ "$entry" == /* ]] ||
      [[ "$entry" == ".." || "$entry" == "../"* ]] ||
      [[ "$entry" == *"/../"* || "$entry" == *"/.." ]]
  then
    die "unsafe archive entry: ${entry}"
  fi

  case "$entry" in
    "BisectHosting.url" | "README.txt" | "$archive_root" | "$archive_root/" | "$archive_root/"*) ;;
    *) die "unexpected archive root in entry: ${entry}" ;;
  esac
done <"$archive_listing"

mkdir "$unpacked_directory"
unzip -q "$archive" -d "$unpacked_directory"

readonly extracted_server="${unpacked_directory}/${archive_root}"
[[ -d "$extracted_server" && ! -L "$extracted_server" ]] ||
  die "archive did not contain the expected ${archive_root} directory"

configure_server "$extracted_server"
printf '%s\n' "$pack_version" >"${extracted_server}/.nix-managed-pack-version"
chmod 0640 "${extracted_server}/.nix-managed-pack-version"

# The staging directory and destination share a filesystem, so this exposes a
# complete verified pack atomically instead of leaving a partial installation.
mv -- "$extracted_server" "$server_directory"
printf 'Installed Exosphere 2 + Create server pack %s.\n' "$pack_version"
