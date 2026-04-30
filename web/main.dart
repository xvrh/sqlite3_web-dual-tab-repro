import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:sqlite_async/sqlite_async.dart';
import 'package:web/web.dart';

/// Opens one `SqliteDatabase`. Multiple browser tabs of this page
/// running concurrently — under cross-origin isolation — race in
/// `sqlite3_web`'s OPFS feature-detection probe and produce a
/// `NoModificationAllowedError` in the worker console.
///
/// Each tab's database itself still opens successfully; the error
/// appears as `Error in worker: NoModificationAllowedError…` in
/// DevTools.
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
    await db.execute('CREATE TABLE IF NOT EXISTS t (id INTEGER PRIMARY KEY)');
    log('OK');
  } catch (e, st) {
    log('FAILED: $e');
    log(st.toString());
  }
}
