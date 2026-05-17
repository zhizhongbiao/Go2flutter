// lib/services/geojson_writer.dart
//
// Converts FlatPointList → GeoJSON FeatureCollection file on disk.
// Uses a StringBuffer-based manual serialiser (3-5× faster than jsonEncode
// on a large list) and streams 10 000-feature chunks to avoid peak-memory spikes.
// Runs in its own Isolate; the UI thread never sees this work.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:path_provider/path_provider.dart';
import '../models/lidar_point.dart';

const _kFileName = 'lawn_lidar_points.geojson';

// ─── Public API ───────────────────────────────────────────────────────────────

/// Writes [flat] as GeoJSON to the temp directory.
/// Returns a `file://` URI string ready for MapLibre's setGeoJsonSource().
Future<String> writeGeoJsonFile(FlatPointList flat) async {
  final dir  = await getTemporaryDirectory();
  final path = '${dir.path}/$_kFileName';

  final rp = ReceivePort();
  await Isolate.spawn(
    _isolateMain,
    _WriteArgs(sendPort: rp.sendPort, flat: flat, path: path),
  );
  await rp.first; // wait for completion signal
  rp.close();

  return 'file://$path';
}

// ─── Isolate internals ────────────────────────────────────────────────────────

class _WriteArgs {
  final SendPort sendPort;
  final FlatPointList flat;
  final String path;
  const _WriteArgs({required this.sendPort, required this.flat, required this.path});
}

void _isolateMain(_WriteArgs args) {
  _write(args.flat, args.path);
  args.sendPort.send(true);
}

void _write(FlatPointList flat, String path) {
  final count = flat.pointCount;
  final sink  = File(path).openSync(mode: FileMode.write);
  final buf   = StringBuffer();

  buf.write('{"type":"FeatureCollection","features":[');

  for (int i = 0; i < count; i++) {
    if (i > 0) buf.write(',');

    final lng = flat.lngAt(i);
    final lat = flat.latAt(i);
    final iv  = flat.intensityAt(i);
    final lbl = flat.labelAt(i);

    // Compact GeoJSON – short property keys save ~20% file size
    buf.write(
      '{"type":"Feature",'
      '"geometry":{"type":"Point","coordinates":[$lng,$lat]},'
      '"properties":{"i":${iv.toStringAsFixed(3)},"t":$lbl}}',
    );

    // Flush every 10 000 features to bound peak memory
    if (i % 10000 == 9999) {
      sink.writeStringSync(buf.toString());
      buf.clear();
    }
  }

  buf.write(']}');
  sink.writeStringSync(buf.toString());
  sink.flushSync();
  sink.closeSync();
}


/// 在 Isolate 中读取 GeoJSON 文件并解析为 Map，避免阻塞 UI 线程
Future<Map<String, dynamic>> readGeoJsonFileAsMap(String fileUri) async {
  final rp = ReceivePort();
  await Isolate.spawn(_readIsolateEntry, _ReadArgs(rp.sendPort, fileUri));
  final result = await rp.first as Map<String, dynamic>;
  rp.close();
  return result;
}

class _ReadArgs {
  final SendPort port;
  final String fileUri;
  const _ReadArgs(this.port, this.fileUri);
}

void _readIsolateEntry(_ReadArgs args) {
  final path = args.fileUri.replaceFirst('file://', '');
  final jsonStr = File(path).readAsStringSync();
  final map = jsonDecode(jsonStr) as Map<String, dynamic>;
  args.port.send(map);
}
