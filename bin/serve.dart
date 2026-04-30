import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

/// Serves `build/` with `Cross-Origin-Embedder-Policy: credentialless` and
/// `Cross-Origin-Opener-Policy: same-origin` so the document is
/// `crossOriginIsolated`. Without this, sqlite3_web takes the IndexedDB
/// fallback path and the bug doesn't trigger.
void main() async {
  // Resolve `build/` relative to this script's location so the server
  // works regardless of cwd.
  final repoRoot = Directory(p.dirname(Platform.script.toFilePath())).parent;
  final buildDir = p.join(repoRoot.path, 'build');

  final handler = const Pipeline()
      .addMiddleware(_addCoepCoop)
      .addHandler(createStaticHandler(buildDir, defaultDocument: 'index.html'));
  final server = await shelf_io.serve(handler, 'localhost', 8765);
  print('Serving $buildDir on http://${server.address.host}:${server.port}');
}

Handler _addCoepCoop(Handler inner) {
  return (req) async {
    final res = await inner(req);
    return res.change(
      headers: {
        'cross-origin-embedder-policy': 'credentialless',
        'cross-origin-opener-policy': 'same-origin',
      },
    );
  };
}
