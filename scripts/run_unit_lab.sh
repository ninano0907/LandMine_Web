#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT=8081
TARGET="${1:-lib/main.dart}"
case "$TARGET" in
  lib/main.dart|lib/unit_lab_main.dart) ;;
  *) echo "Unsupported Flutter entry point: $TARGET" >&2; exit 1 ;;
esac

listeners() {
  lsof -nP -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true
}

PIDS="$(listeners)"
if [[ -n "$PIDS" ]]; then
  echo "Stopping processes listening on port $PORT: $PIDS"
  while IFS= read -r pid; do
    kill -TERM "$pid"
  done <<< "$PIDS"
  for attempt in {1..30}; do
    [[ -z "$(listeners)" ]] && break
    sleep 0.1
  done
  # Only force-stop original listeners that still own this port.
  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    if printf '%s\n' "$PIDS" | grep -Fxq -- "$pid"; then
      kill -KILL "$pid"
    fi
  done <<< "$(listeners)"
fi
if [[ -n "$(listeners)" ]]; then
  echo "Port $PORT is still occupied; refusing to launch a duplicate server." >&2
  exit 1
fi
cd "$PROJECT_ROOT/app"
mkdir -p .dart_tool
exec flutter run -d chrome -t "$TARGET" --web-port "$PORT" --pid-file .dart_tool/unit_lab.pid
