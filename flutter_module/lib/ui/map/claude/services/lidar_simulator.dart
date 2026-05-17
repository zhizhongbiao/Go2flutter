// lib/services/lidar_simulator.dart
//
// Simulates a LiDAR-equipped lawn mower scanning a 100m × 80m garden.
// Produces ~300 000 points with realistic spatial patterns.
// Runs entirely inside a dedicated Isolate → UI thread never stalls.
//
// Data layout (FlatPointList):
//   [ lng0, lat0, intensity0, label0,  lng1, lat1, … ]

import 'dart:isolate';
import 'dart:math';
import 'package:flutter_module/ui/map/constants.dart';

import '../models/lidar_point.dart';

// ─── Public API ───────────────────────────────────────────────────────────────

class SimulatorConfig {
  final double originLng;
  final double originLat;
  final int targetPoints;

  const SimulatorConfig({
    this.originLng = kLng,
    this.originLat  = kLat,
    this.targetPoints = kPoints,
  });
}

/// Spawn an Isolate, generate [config.targetPoints] LiDAR points, return flat list.
Future<FlatPointList> runSimulatorInIsolate(SimulatorConfig config) async {
  final rp = ReceivePort();
  await Isolate.spawn(_isolateMain, _IsolateArgs(rp.sendPort, config));
  final result = await rp.first as FlatPointList;
  rp.close();
  return result;
}

// ─── Isolate internals ────────────────────────────────────────────────────────

class _IsolateArgs {
  final SendPort port;
  final SimulatorConfig cfg;
  const _IsolateArgs(this.port, this.cfg);
}

void _isolateMain(_IsolateArgs args) {
  final flat = _generate(args.cfg);
  args.port.send(flat);
}

// ─── Generation logic ─────────────────────────────────────────────────────────
//
// Garden coordinate system: origin at SW corner, X = east (metres), Y = north.
// Converted to WGS-84 lon/lat offsets for MapLibre.

const _lawnW = 100.0; // metres east
const _lawnH = 80.0;  // metres north

// Fixed obstacles: (cx, cy, radius) in metres from SW origin
const _obstacles = [
  (25.0, 20.0, 3.5),
  (70.0, 15.0, 2.2),
  (50.0, 50.0, 4.0),
  (15.0, 60.0, 2.5),
  (82.0, 55.0, 3.2),
  (40.0, 70.0, 1.8),
  (60.0, 35.0, 2.6),
  (30.0, 45.0, 1.5),
];

FlatPointList _generate(SimulatorConfig cfg) {
  // Degree-per-metre conversion at origin latitude
  const mPerDegLat = 111320.0;
  final mPerDegLng = mPerDegLat * cos(cfg.originLat * pi / 180);

  final rng  = Random(0xDEADBEEF); // fixed seed → reproducible
  // Pre-allocate: 4 doubles per point
  final out  = List<double>.filled(cfg.targetPoints * 4, 0.0, growable: false);
  int   idx  = 0;

  void emit(double mx, double my, double intensity, int label) {
    if (idx + 3 >= out.length) return;
    out[idx++] = cfg.originLng + mx / mPerDegLng;
    out[idx++] = cfg.originLat + my / mPerDegLat;
    out[idx++] = intensity.clamp(0.0, 1.0);
    out[idx++] = label.toDouble();
  }

  // ── 1. Mown-grass dense grid (55 % of points) ──────────────────────────
  // Simulates boustrophedon (snake) mowing path with sensor jitter.
  final grassTarget = (cfg.targetPoints * 0.55).toInt();
  final rows = sqrt(grassTarget).toInt();
  final cols = (grassTarget / rows).ceil();

  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final mc = (r.isEven) ? c : (cols - 1 - c); // snake direction
      final mx = (mc / cols) * _lawnW + rng.nextDouble() * (_lawnW / cols) * 0.5;
      final my = (r  / rows) * _lawnH + rng.nextDouble() * (_lawnH / rows) * 0.5;

      // Skip if inside an obstacle circle
      if (_inObstacle(mx, my)) continue;

      final intensity = 0.04 + rng.nextDouble() * 0.22; // low = flat grass
      emit(mx, my, intensity, PointLabel.grass.index);
    }
  }

  // ── 2. Obstacles (trees / rocks) – 12 % ───────────────────────────────
  final obsTarget = (cfg.targetPoints * 0.12).toInt();
  final perObs    = obsTarget ~/ _obstacles.length;

  for (final (cx, cy, rad) in _obstacles) {
    // Dense core + sparse halo to mimic LiDAR multi-return
    for (int i = 0; i < perObs; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      // Bias toward perimeter (sqrt for uniform area distribution)
      final r  = sqrt(rng.nextDouble()) * rad * (i < perObs * 0.7 ? 1.0 : 1.6);
      final mx = cx + r * cos(angle);
      final my = cy + r * sin(angle);
      // Intensity: very high returns from solid objects
      final intensity = 0.72 + rng.nextDouble() * 0.28;
      emit(mx, my, intensity, PointLabel.obstacle.index);
    }
  }

  // ── 3. Boundary ring (15 %) ────────────────────────────────────────────
  final boundTarget = (cfg.targetPoints * 0.15).toInt();
  final perim       = 2 * (_lawnW + _lawnH);

  for (int i = 0; i < boundTarget; i++) {
    final t   = rng.nextDouble() * perim;
    double mx, my;

    if (t < _lawnW) {
      mx = t;              my = rng.nextDouble() * 0.6;
    } else if (t < _lawnW + _lawnH) {
      mx = _lawnW - rng.nextDouble() * 0.6; my = t - _lawnW;
    } else if (t < 2 * _lawnW + _lawnH) {
      mx = 2 * _lawnW + _lawnH - t;         my = _lawnH - rng.nextDouble() * 0.6;
    } else {
      mx = rng.nextDouble() * 0.6;           my = perim - t;
    }

    emit(mx, my, 0.88 + rng.nextDouble() * 0.12, PointLabel.boundary.index);
  }

  // ── 4. Sensor noise / unknowns (remainder) ────────────────────────────
  while (idx < out.length - 4) {
    final mx = rng.nextDouble() * _lawnW;
    final my = rng.nextDouble() * _lawnH;
    emit(mx, my, rng.nextDouble(), PointLabel.unknown.index);
  }

  return out;
}

bool _inObstacle(double mx, double my) {
  for (final (cx, cy, rad) in _obstacles) {
    final dx = mx - cx, dy = my - cy;
    if (dx * dx + dy * dy < rad * rad) return true;
  }
  return false;
}
