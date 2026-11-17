#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec bash "$PROJECT_ROOT/scripts/run_unit_lab.sh" lib/main.dart
