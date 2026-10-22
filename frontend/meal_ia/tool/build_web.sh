#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Render's static build image does not include Flutter.
if ! command -v flutter >/dev/null 2>&1; then
  SDK_DIR="${RENDER_FLUTTER_SDK_DIR:-/tmp/mealia-flutter-3.44.0}"
  if [ ! -x "$SDK_DIR/bin/flutter" ]; then
    git clone --depth 1 --branch 3.44.0 https://github.com/flutter/flutter.git "$SDK_DIR"
  fi
  export PATH="$SDK_DIR/bin:$PATH"
fi
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
export TAR_OPTIONS=--no-same-owner
python3 tool/prepare_client_env.py
flutter pub get
flutter build web --release --no-wasm-dry-run --no-web-resources-cdn
