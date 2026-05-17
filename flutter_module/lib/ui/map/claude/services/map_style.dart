// lib/services/map_style.dart
//
// Offline dark-theme MapLibre style.
// No external tile server required – base map is a solid dark canvas so
// 100% of GPU budget goes to our point cloud layer.

/// Inline MapLibre GL style JSON (version 8).
const String kOfflineDarkStyle = '''
{
  "version": 8,
  "name": "LiDAR Dark",
  "sources": {},
  "layers": [
    {
      "id": "background",
      "type": "background",
      "paint": { "background-color": "#080f09" }
    }
  ],
  "glyphs": "https://demotiles.maplibre.org/font/{fontstack}/{range}.pbf"
}
''';

// ─── Source IDs ───────────────────────────────────────────────────────────────

const kSourceId          = 'lidar-source';
const kClusterLayerId    = 'lidar-clusters';
const kClusterCountId    = 'lidar-cluster-count';
const kPointLayerId      = 'lidar-points';

// ─── MapLibre data-driven expressions ────────────────────────────────────────
//
// These run entirely on the GPU/render thread; no Dart CPU cost per frame.
// Property "t" = label index (0=grass 1=obstacle 2=boundary 3=unknown)
// Property "i" = intensity float 0-1

/// circle-color expression keyed on label property "t"
const kCircleColorExpr = [
  'match', ['get', 't'],
  0, '#1db954',   // grass   – Spotify green
  1, '#ff3b3b',   // obstacle – vivid red
  2, '#ffd700',   // boundary – gold
  3, '#546454',   // unknown  – muted grey-green
  '#546454',      // fallback
];

/// circle-radius interpolated by zoom level
const kCircleRadiusExpr = [
  'interpolate', ['linear'], ['zoom'],
  10, 1.0,
  13, 1.8,
  15, 3.0,
  17, 5.5,
  19, 10.0,
];

/// cluster circle colour by point count
const kClusterColorExpr = [
  'step', ['get', 'point_count'],
  '#1a5e2e',   // < 200
  200,  '#2d9e4a',
  2000, '#52d46e',
];

/// cluster circle radius by point count
const kClusterRadiusExpr = [
  'step', ['get', 'point_count'],
  14,
  200,  22,
  2000, 32,
];
