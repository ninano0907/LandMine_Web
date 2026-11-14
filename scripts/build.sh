#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Count source commits to give each pushed revision a monotonically increasing label.
if git rev-parse --is-shallow-repository | grep -qx true; then
  git fetch --unshallow --quiet
fi
BUILD_NUMBER="$(git rev-list --count HEAD)"
cd app
flutter pub get
flutter build web --release --dart-define=BUILD_NUMBER="$BUILD_NUMBER" --base-href /LandMine_Web/ --no-web-resources-cdn --pwa-strategy=none --no-tree-shake-icons
cd ..
cp -R app/build/web/. .
python3 scripts/service_worker.py
touch .nojekyll
