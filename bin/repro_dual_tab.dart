import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:puppeteer/puppeteer.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

/// Opens N real-Chrome tabs concurrently against a COEP/COOP-served
/// page that runs one `SqliteDatabase`. Watches every tab's console
/// for `NoModificationAllowedError` from `sqlite3_web`'s OPFS feature
/// detection.
///
///   dart run bin/repro_dual_tab.dart [--tabs 5] [--attempts 1]
Future<void> main(List<String> args) async {
  final tabs = _arg(args, '--tabs', 5);
  final attempts = _arg(args, '--attempts', 1);

  final repoRoot = Directory(p.dirname(Platform.script.toFilePath())).parent;
  final buildDir = p.join(repoRoot.path, 'build');
  final server = await _serve(buildDir);
  final url = 'http://localhost:${server.port}/';
  print('serving $url ($tabs tabs × $attempts attempts)');

  final browser = await puppeteer.launch(headless: false);

  try {
    var hits = 0;
    for (var i = 1; i <= attempts; i++) {
      if (await _attempt(browser, url, tabs)) {
        hits++;
        print('attempt $i: HIT');
      } else {
        print('attempt $i: clean');
      }
    }
    print('\n$hits/$attempts attempts triggered NoModificationAllowedError');
  } finally {
    await browser.close();
    await server.close(force: true);
  }
}

/// Returns true iff at least one tab logged NoModificationAllowedError.
Future<bool> _attempt(Browser browser, String url, int tabCount) async {
  final pages = await Future.wait([
    for (var i = 0; i < tabCount; i++) browser.newPage(),
  ]);

  final logs = [for (final _ in pages) <String>[]];
  for (var i = 0; i < pages.length; i++) {
    final sink = logs[i];
    pages[i].onConsole.listen((m) => sink.add(m.text ?? ''));
  }

  await Future.wait([for (final p in pages) p.goto(url, wait: Until.load)]);
  // Page prints OK / FAILED to a <pre id="status">. Some tabs HANG
  // without ever reaching either when the worker errors out — swallow
  // individual per-tab timeouts (we still scan their logs).
  for (final p in pages) {
    try {
      await p.waitForFunction(
        '() => /OK|FAILED/.test(document.getElementById("status").textContent)',
        timeout: const Duration(seconds: 5),
      );
    } catch (_) {
      // tab is hanging — that's also a symptom; carry on.
    }
  }

  final hit = logs.any(
    (l) => l.any((line) => line.contains('NoModificationAllowedError')),
  );
  if (hit) {
    for (var i = 0; i < logs.length; i++) {
      final line = logs[i].firstWhere(
        (l) => l.contains('NoModificationAllowedError'),
        orElse: () => '',
      );
      if (line.isNotEmpty) print('  tab${i + 1}: $line');
    }
  }

  await Future.wait([for (final p in pages) p.close()]);
  return hit;
}

int _arg(List<String> args, String key, int fallback) {
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == key) return int.parse(args[i + 1]);
  }
  return fallback;
}

Future<HttpServer> _serve(String buildDir) {
  Handler addCoepCoop(Handler inner) => (req) async => (await inner(req))
      .change(headers: {
        'cross-origin-embedder-policy': 'credentialless',
        'cross-origin-opener-policy': 'same-origin',
      });
  final h = const Pipeline()
      .addMiddleware(addCoepCoop)
      .addHandler(createStaticHandler(buildDir, defaultDocument: 'index.html'));
  // Port 0 → OS picks a free port. Avoids collisions with anything else
  // bound to 8765 (e.g. a manually-running `bin/serve.dart`).
  return shelf_io.serve(h, 'localhost', 0);
}
