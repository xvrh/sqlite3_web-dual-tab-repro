#!/usr/bin/env bash
# Re-build the reproduction. Run this after editing web/main.dart.
# Outputs to build/.

set -euo pipefail

# Match the versions in pubspec.yaml. `db_worker.js` and `sqlite3.wasm`
# are pulled from upstream releases — sqlite_async ships a prebuilt
# worker, so we don't compile our own.
SQLITE_ASYNC_VERSION="${SQLITE_ASYNC_VERSION:-0.14.1}"
SQLITE3_VERSION="${SQLITE3_VERSION:-3.3.1}"

WORKER_URL="https://github.com/powersync-ja/sqlite_async.dart/releases/download/sqlite_async-v${SQLITE_ASYNC_VERSION}/db_worker.js"
WASM_URL="https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-${SQLITE3_VERSION}/sqlite3.wasm"

mkdir -p build
cp web/index.html build/

if [ ! -f build/db_worker.js ]; then
  echo "Downloading db_worker.js v${SQLITE_ASYNC_VERSION}…"
  curl -fL --output build/db_worker.js "$WORKER_URL"
fi

if [ ! -f build/sqlite3.wasm ]; then
  echo "Downloading sqlite3.wasm v${SQLITE3_VERSION}…"
  curl -fL --output build/sqlite3.wasm "$WASM_URL"
fi

# `dart` must point at an SDK matching pubspec.yaml's constraint (>=3.9).
DART="${DART:-dart}"

echo "Compiling main.dart…"
"$DART" compile js -O0 web/main.dart -o build/main.dart.js

echo "Done. Run \`$DART run bin/serve.dart\` then open http://localhost:8765/."
