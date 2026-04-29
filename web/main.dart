import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:sqlite_async/sqlite_async.dart';
import 'package:web/web.dart';

/// Minimal `sqlite_async` consumer. Opens a `SqliteDatabase` and runs a
/// no-op schema statement. That's enough to walk through:
///
///   sqlite_async  →  sqlite3_web feature detection  →  pick OPFS impl  →  open db
///
/// Two browser tabs starting that flow concurrently under
/// `crossOriginIsolated` is what triggers the upstream
/// `NoModificationAllowedError`.
void main() async {
  final status = document.getElementById('status') as HTMLPreElement;
  void log(String s) {
    status.textContent = '${status.textContent}\n$s';
    print(s);
  }

  log('crossOriginIsolated: ${globalContext.getProperty('crossOriginIsolated'.toJS)}');

  try {
    final db = SqliteDatabase(
      path: 'repro_db',
      options: const SqliteOptions(webSqliteOptions: WebSqliteOptions()),
    );
    log('SqliteDatabase created, awaiting first query…');
    await db.execute(
      'CREATE TABLE IF NOT EXISTS t (id INTEGER PRIMARY KEY)',
    );
    log('OK');
  } catch (e) {
    log('FAILED: $e');
  }
}
