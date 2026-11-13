#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../app"
flutter pub get
flutter build web --release --base-href /LandMine_Web/ --no-web-resources-cdn --pwa-strategy=none --no-tree-shake-icons
cd ..
cp -R app/build/web/. .
python3 scripts/service_worker.py
touch .nojekyll
