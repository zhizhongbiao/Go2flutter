// lib/models/lidar_point.dart
//
// Flat data model for a single LiDAR return.
// Kept intentionally lean – no heavy OOP – so Isolate serialisation is fast.

enum PointLabel {
  grass,     // index 0 – mowed area, low reflectivity
  obstacle,  // index 1 – tree/rock/object, high reflectivity
  boundary,  // index 2 – lawn edge marker
  unknown,   // index 3 – unclassified noise
}

/// Flat quad: [lng, lat, intensity(0-1), labelIndex]
/// Stored as List<double> across the entire dataset for zero-copy Isolate transfer.
typedef FlatPointList = List<double>;

extension FlatPointListExt on FlatPointList {
  int get pointCount => length ~/ 4;

  double lngAt(int i)       => this[i * 4];
  double latAt(int i)       => this[i * 4 + 1];
  double intensityAt(int i) => this[i * 4 + 2];
  int    labelAt(int i)     => this[i * 4 + 3].toInt();
}
