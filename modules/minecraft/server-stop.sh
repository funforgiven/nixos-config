set -euo pipefail

readonly program_name="${0##*/}"

if [[ "$#" -ne 2 ]]; then
  printf '%s: expected console FIFO and server PID\n' "$program_name" >&2
  exit 1
fi

readonly console_fifo="$1"
readonly server_pid="$2"

if [[ ! -p "$console_fifo" ]]; then
  printf '%s: console FIFO is unavailable: %s\n' "$program_name" "$console_fifo" >&2
  exit 1
fi

printf 'stop\n' >"$console_fifo"

# Let Minecraft finish saving before systemd proceeds to its final kill phase.
while kill -0 "$server_pid" 2>/dev/null; do
  sleep 1
done
