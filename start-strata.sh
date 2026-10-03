#!/bin/bash
# start-strata.sh [profile|--print [profile]] - start the Strata server detached inside WSL.
#   Reads .env-<profile> (or .env) next to this script; see .env.example for all settings.
#   --print shows the resolved settings (API_KEY masked) without starting anything.
set -u
HERE="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")" && pwd)"
PRINT=0
if [ "${1:-}" = "--print" ]; then PRINT=1; shift; fi
PROFILE="${1:-default}"
ENV_FILE="$HERE/.env-$PROFILE"
[ -f "$ENV_FILE" ] || ENV_FILE="$HERE/.env"
[ -f "$ENV_FILE" ] || { echo "NO_ENV_FILE: expected $HERE/.env-$PROFILE or $HERE/.env"; exit 1; }

get() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$ENV_FILE" | tr -d '\r' | head -1; }

API_KEY="$(get API_KEY)"
MODEL="$(get MODEL)"
CONFIG_NAME="$(get CONFIG_NAME)"
STRATA_DIR="$(get STRATA_DIR)"; STRATA_DIR="${STRATA_DIR:-$HOME/Strata}"
PORT="$(get PORT)"; PORT="${PORT:-8080}"
HOST="$(get HOST)"; HOST="${HOST:-127.0.0.1}"
GPU_IDS="$(get GPU_IDS)"; GPU_IDS="${GPU_IDS:-0}"
USE_ESP="$(get USE_ESP)"; USE_ESP="${USE_ESP:-0}"
PF_FUSED="$(get STRATA_PF_FUSED)"; PF_FUSED="${PF_FUSED:-1}"
FIT_MAX_TOKENS="$(get FIT_MAX_TOKENS)"; FIT_MAX_TOKENS="${FIT_MAX_TOKENS:-1}"

if [ "$PRINT" = "1" ]; then
  echo "env_file   = $ENV_FILE"
  echo "API_KEY    = $([ -n "$API_KEY" ] && echo '<set>' || echo '<MISSING>')"
  echo "MODEL      = ${MODEL:-<MISSING>}"
  echo "CONFIG     = ${CONFIG_NAME:-strata-$MODEL.json}"
  echo "STRATA_DIR = $STRATA_DIR"
  echo "PORT/HOST  = $PORT / $HOST"
  echo "GPU_IDS    = $GPU_IDS"
  echo "USE_ESP    = $USE_ESP"
  echo "PF_FUSED   = $PF_FUSED"
  echo "FIT_MAX    = $FIT_MAX_TOKENS"
  exit 0
fi

[ -n "$API_KEY" ] || { echo "NO_API_KEY in $ENV_FILE"; exit 1; }
[ -n "$MODEL" ] || { echo "NO_MODEL in $ENV_FILE"; exit 1; }
CONFIG_NAME="${CONFIG_NAME:-strata-$MODEL.json}"
cd "$STRATA_DIR" || { echo "NO_STRATA_DIR: $STRATA_DIR"; exit 1; }
[ -f "$CONFIG_NAME" ] || { echo "NO_CONFIG: $STRATA_DIR/$CONFIG_NAME"; exit 1; }
LOG="serve-$MODEL.out"

# USE_ESP=0: strip the control-vector arguments into a derived config (original untouched).
CONFIG="$CONFIG_NAME"
if [ "$USE_ESP" != "1" ]; then
  CONFIG="/tmp/strata-noesp-$MODEL.json"
  ./.venv/bin/python - "$CONFIG_NAME" "$CONFIG" <<'PY'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
cfg = json.load(open(src))
drop = {"--control-vector-scaled", "--control-vector-layer-range", "--cvec-mode", "--cvec-dir"}
args, keep = cfg.get("args", []), []
i = 0
while i < len(args):
    if args[i] in drop:
        i += 1
        while i < len(args) and not args[i].startswith("--"):
            i += 1
    else:
        keep.append(args[i]); i += 1
cfg["args"] = keep
json.dump(cfg, open(dst, "w"), indent=1)
PY
  [ -f "$CONFIG" ] || { echo "CONFIG_FILTER_FAILED"; exit 1; }
fi

rm -f "$LOG"
export STRATA_PF_FUSED="$PF_FUSED"
EXTRA_ARGS=""
[ "$FIT_MAX_TOKENS" = "1" ] && EXTRA_ARGS="--fit-max-tokens"
setsid nohup ./.venv/bin/python -u serve/server.py --engine strata --config "$CONFIG" \
  --port "$PORT" --host "$HOST" --gpu "$GPU_IDS" $EXTRA_ARGS --api-key "$API_KEY" \
  > "$LOG" 2>&1 < /dev/null &
sleep 2
if pgrep -f 'serve''/server.py' >/dev/null; then
  echo "LAUNCHED model=$MODEL port=$PORT gpu=$GPU_IDS esp=$USE_ESP"
else
  echo "LAUNCH_FAILED (check $STRATA_DIR/$LOG)"
  exit 1
fi
