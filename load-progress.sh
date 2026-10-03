#!/bin/bash
# load-progress.sh - Strata loading progress / readiness for the Windows launcher.
# usage: load-progress.sh health <port>
#        load-progress.sh progress <port> <serve-log-path> <gpu-index> [resident-total-gib]
set -u
MODE="${1:-health}"
PORT="${2:-8080}"

if [ "$MODE" = "health" ]; then
  MC=$(curl -s --max-time 3 "http://127.0.0.1:$PORT/health" 2>/dev/null | grep -o '"max_context": *[0-9]*' | grep -o '[0-9]*')
  if [ "${MC:-0}" -gt 0 ] 2>/dev/null; then echo READY; else echo STARTING; fi
  exit 0
fi

LOG="${3:-}"
GPU="${4:-0}"
TOTAL="${5:-76}"
if [ -z "$LOG" ]; then echo "no log path given"; exit 0; fi
E=$(pgrep -f 'engine''/strata' | head -1)
if [ -z "$E" ]; then echo "engine not running yet"; exit 0; fi
RSS_KB=$(awk '/VmRSS/{print $2}' "/proc/$E/status" 2>/dev/null)
if [ -z "$RSS_KB" ]; then echo "engine process gone"; exit 0; fi
RSS_G=$(awk -v k="$RSS_KB" 'BEGIN{printf "%.1f", k/1048576}')
PCT=$(awk -v k="$RSS_KB" -v t="$TOTAL" 'BEGIN{p=k/1048576/t*100; if(p>99)p=99; if(p<0)p=0; printf "%d", p}')
VRAM=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits -i "$GPU" 2>/dev/null)
STAGE=$(grep -o '\[strata\][^(]*' "$LOG" 2>/dev/null | tail -1 | cut -c1-56)
echo "RAM ${RSS_G}GiB (${PCT}%) | GPU ${VRAM}MiB | ${STAGE}"
