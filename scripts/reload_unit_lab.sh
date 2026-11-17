#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$PROJECT_ROOT/app/.dart_tool/unit_lab.pid"
if [[ ! -f "$PID_FILE" ]]; then
  echo '게임을 실행 버튼으로 한 번 다시 시작해 주세요.' >&2
  exit 1
fi
PID="$(cat "$PID_FILE")"
if [[ ! "$PID" =~ ^[0-9]+$ ]]; then
  echo 'Invalid Flutter process ID.' >&2
  exit 1
fi
COMMAND="$(ps -p "$PID" -o command= || true)"
if [[ "$COMMAND" != *flutter_tools* || "$COMMAND" != *lib/main.dart* && "$COMMAND" != *lib/unit_lab_main.dart* || "$COMMAND" != *unit_lab.pid* ]]; then
  echo '게임 Flutter 프로세스가 실행 중이 아닙니다.' >&2
  exit 1
fi
case "${1:-reload}" in
  reload) kill -USR1 "$PID" ;;
  restart) kill -USR2 "$PID" ;;
  *) echo 'Usage: reload_unit_lab.sh [reload|restart]' >&2; exit 1 ;;
esac
echo "Flutter ${1:-reload} requested."
