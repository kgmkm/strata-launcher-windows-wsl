#!/bin/bash
# stop-strata.sh [profile] - stop the Strata server for that profile.
# Closes the server and its engine only. Does NOT shut down the WSL VM.
set -u
HERE="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")" && pwd)"
PROFILE="${1:-default}"
ENV_FILE="$HERE/.env-$PROFILE"
[ -f "$ENV_FILE" ] || ENV_FILE="$HERE/.env"
[ -f "$ENV_FILE" ] || { echo "NO_ENV_FILE: expected $HERE/.env-$PROFILE or $HERE/.env"; exit 1; }

get() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$ENV_FILE" | tr -d '\r' | head -1; }
PORT="$(get PORT)"; PORT="${PORT:-8080}"
MODEL="$(get MODEL)"; MODEL="${MODEL:-?}"

# Match the server by its command line. Do not use pkill -f: that pattern can
# match the shell that is running this script and kill it.
found=0
for pid in $(pgrep -f 'serve/server.py' || true); do
  cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)
  case "$cmd" in
    *" --port $PORT "*|*" --port $PORT"|*"--port=$PORT"*)
      found=1
      for child in $(ps -o pid= --ppid "$pid" 2>/dev/null); do
        kill "$child" 2>/dev/null || true
      done
      kill "$pid" 2>/dev/null || true
      echo "STOP_SENT model=$MODEL port=$PORT pid=$pid"
      ;;
  esac
done

if [ "$found" = "0" ]; then
  echo "NOT_RUNNING model=$MODEL port=$PORT"
  exit 0
fi

sleep 2
still=0
for pid in $(pgrep -f 'serve/server.py' || true); do
  cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)
  case "$cmd" in
    *" --port $PORT "*|*" --port $PORT"|*"--port=$PORT"*)
      kill -9 "$pid" 2>/dev/null || true
      still=1
      ;;
  esac
done
[ "$still" = "1" ] && sleep 1
echo "STOPPED model=$MODEL port=$PORT"
