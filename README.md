# sqlite3_web `NoModificationAllowedError` repro

Multiple browser tabs concurrently opening a `SqliteDatabase`
(`sqlite_async`, which builds on `sqlite3_web`) under cross-origin
isolation race in `sqlite3_web`'s OPFS feature-detection probe and
produce:

```
Error in worker: NoModificationAllowedError: Failed to execute
'removeEntry' on 'FileSystemDirectoryHandle': An attempt was made to
modify an object where modifications are not allowed.
```

The error is logged from inside the worker. **`sqlite3_web` absorbs
it** in this single-`SqliteDatabase` consumer — the database itself
still opens successfully, the page prints `OK`, `drift_db/` lands in
OPFS as expected. So the immediate user-visible effect is just a
noisy console.

In our application stack (`sqlite_async` + drift + powersync, multiple
databases per tab), the same race appears alongside a downstream hang
(the page never recovers, sync stops working until the powersync
shared-worker is manually killed). We have not reduced that downstream
effect to a minimal repro — this repo only demonstrates the upstream
error.

## Manual reproduction (one click)

1. Run `dart pub get && dart run bin/serve.dart`.
2. Open `http://localhost:8765/launcher.html` in **real top-level
   Chrome** (not in a preview / iframe — the page must be
   `crossOriginIsolated`).
3. Open DevTools (Cmd+Option+I).
4. Allow popups for `localhost` if Chrome blocks them.
5. Click the "Spawn N sibling tabs" button — opens 5 popups, each
   running `web/main.dart` (one `SqliteDatabase` open).
6. In any spawned tab's DevTools console, you'll see the
   `NoModificationAllowedError`.

## Automated reproduction

```bash
dart run bin/repro_dual_tab.dart                  # 5 tabs × 1 attempt
dart run bin/repro_dual_tab.dart --tabs 8 --attempts 5
```

Launches puppeteer Chrome (real top-level windows — preview
environments iframe pages, which breaks `crossOriginIsolated`), opens
N tabs concurrently against a COEP+COOP-served local page, and scans
every tab's console for the error. The script binds to a free OS-picked
port so it doesn't collide with a manually-running `bin/serve.dart`.

Output looks like:
```
serving http://localhost:53412/ (5 tabs × 1 attempts)
  tab2: Error in worker: NoModificationAllowedError…
  tab3: Error in worker: NoModificationAllowedError…
  tab4: Error in worker: NoModificationAllowedError…
attempt 1: HIT
1/1 attempts triggered NoModificationAllowedError
```

## Re-build

After editing `web/main.dart`:

```bash
./compile.sh
```

Pulls `db_worker.js` (sqlite_async release) and `sqlite3.wasm`
(simolus3/sqlite3.dart release) into `build/` if not already there,
then compiles `web/main.dart` to `build/main.dart.js`.

## Files

```
web/
├── index.html        ← page each spawned tab loads
├── main.dart         ← one SqliteDatabase open per tab
└── launcher.html     ← single-click manual repro

bin/
├── serve.dart        ← shelf server with COEP/COOP, port 8765
└── repro_dual_tab.dart  ← puppeteer driver (auto-port)

compile.sh            ← build everything into build/
build/                ← prebuilt artifacts (clone-and-run)
```

## Versions

- `sqlite_async 0.14.1`
- `sqlite3_web 0.7.0` (transitive, where the race lives)
- `sqlite3 3.3.1` (matching `sqlite3.wasm`)
- Dart SDK 3.12.0-327.3.beta (Flutter 3.44.0-0.2.pre, beta channel)
- Chrome 138, macOS arm64
- `puppeteer ^3.18.0` (dev dep, drives the automated form)
