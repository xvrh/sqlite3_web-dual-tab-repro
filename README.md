# sqlite3_web dual-tab init repro

Reproduces a `NoModificationAllowedError` thrown from a `sqlite3_web`
worker when two browser tabs initialize a database concurrently under
cross-origin isolation.

The repro is a `sqlite_async` consumer (the typical entry point — drift
and PowerSync both wrap it). The bug lives one layer down in
`sqlite3_web`'s feature-detection probe.

See the upstream issue this repo accompanies: <link>.

## What this is

Minimal Dart-only project (no Flutter dep). One static HTML page +
one compiled-to-JS Dart module + a small Dart server that adds the
COEP/COOP headers required for `crossOriginIsolated`. `db_worker.js`
and `sqlite3.wasm` come from upstream releases — we don't recompile
them, the same way a real consumer wouldn't.

## Run the prebuilt repro

Pre-compiled `main.dart.js`, plus the matching `db_worker.js` and
`sqlite3.wasm`, are already in `build/`.

```bash
dart pub get
dart run bin/serve.dart
```

Then in Chrome:

1. Open <http://localhost:8765/>. Wait for `OK` to appear in the page.
2. Hard-reload that tab (Cmd+Shift+R / Ctrl+Shift+R).
3. **Within ~1 second**, open the same URL in a second Chrome tab.
4. Second tab's DevTools console emits:

```
NoModificationAllowedError: Failed to execute 'removeEntry' on
'FileSystemDirectoryHandle': An attempt was made to modify an object
where modifications are not allowed.
```

…and the page hangs at "starting…".

`self.crossOriginIsolated === true` is required to reproduce — the
included `bin/serve.dart` sets the headers; verify in the console
before doing the dual-tab dance.

Reliability ~80% on Chrome 138 / macOS arm64 with the timing above.
Closing both tabs and waiting 5–10 seconds restores a clean state.

## Re-build

After editing `web/main.dart`:

```bash
./compile.sh
```

Pulls `db_worker.js` (sqlite_async release) and `sqlite3.wasm`
(simolus3/sqlite3.dart release) into `build/` if not already there,
then compiles `web/main.dart` to `build/main.dart.js`.

## Versions

- `sqlite_async 0.14.1`
- `sqlite3_web 0.7.0` (transitive, where the issue lives)
- `sqlite3 3.3.1` (matching `sqlite3.wasm`)
- Dart SDK 3.12.0-327.3.beta (Flutter 3.44.0-0.2.pre, beta channel)
- Chrome 138, macOS arm64
