// lib/services/map_layer_service.dart
//
// Wraps MapLibreMapController to:
//   • add GeoJSON source with clustering enabled
//   • add cluster + individual-point circle layers
//   • hot-swap source data (setGeoJsonSource) for incremental updates
//   • animate camera to fit data bounds

import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'geojson_writer.dart';
import 'map_style.dart';

// Approximate bounding box of the simulated lawn (degrees)
// SW = origin, NE = origin + 100m east + 80m north
// At lat 22.524°:  100m ≈ 0.000899°lng,  80m ≈ 0.000719°lat
const _kDefaultBoundsSwLng = 113.9260;
const _kDefaultBoundsSwLat = 22.5240;
const _kDefaultBoundsNeLng = 113.9260 + 0.000899;
const _kDefaultBoundsNeLat = 22.5240 + 0.000719;

class MapLayerService {
  MapLibreMapController? _ctrl;
  bool _initialised = false;

  void attach(MapLibreMapController c) => _ctrl = c;

  void detach() {
    _ctrl = null;
    _initialised = false;
  }

  bool get isReady => _ctrl != null;

  // ─── First-time setup ─────────────────────────────────────────────────────

  /// Call once after MapLibre style has loaded.
  /// [fileUri] = file:// path returned by writeGeoJsonFile().
  Future<void> initialise(String fileUri) async {
    final c = _ctrl;
    if (c == null) return;

    try {
      // ── GeoJSON source with clustering ──────────────────────────────────
      await c.addSource(
        kSourceId,
        GeojsonSourceProperties(
          data: fileUri,        // file:// → MapLibre streams it internally
          maxzoom: 18,          // tile resolution cap
          buffer: 64,           // tile buffer in pixels (reduces edge artifacts)
          tolerance: 0.5,       // Douglas-Peucker simplification at low zoom
          cluster: true,        // GPU-side spatial clustering
          clusterMaxZoom: 13,   // individual points visible above zoom 13
          clusterRadius: 50,    // cluster merge radius in pixels
        ),
      );

      // ── Cluster circles ─────────────────────────────────────────────────
      await c.addCircleLayer(
        kSourceId,
        kClusterLayerId,
        CircleLayerProperties(
          circleRadius: kClusterRadiusExpr,
          circleColor: kClusterColorExpr,
          circleOpacity: 0.78,
          circleStrokeWidth: 1.5,
          circleStrokeColor: '#ffffff',
          circleStrokeOpacity: 0.20,
        ),
        filter: ['has', 'point_count'],   // only cluster features
      );

      // ── Cluster count labels ────────────────────────────────────────────
      await c.addSymbolLayer(
        kSourceId,
        kClusterCountId,
        SymbolLayerProperties(
          textField: [
            'number-format',
            ['get', 'point_count_abbreviated'],
            <String, dynamic>{},
          ],
          textSize: 11,
          textColor: '#e8ffe8',
          textFont: ['Open Sans Bold', 'Arial Unicode MS Bold'],
          textAllowOverlap: true,
        ),
        filter: ['has', 'point_count'],
      );

      // ── Individual point circles (visible above clusterMaxZoom) ─────────
      await c.addCircleLayer(
        kSourceId,
        kPointLayerId,
        CircleLayerProperties(
          circleRadius: kCircleRadiusExpr,   // zoom-interpolated
          circleColor: kCircleColorExpr,     // label-driven colour
          circleOpacity: 0.86,
          circleBlur: 0.12,
          // No stroke – saves fill+stroke draw calls at 300k points
        ),
        filter: ['!', ['has', 'point_count']],  // exclude cluster features
      );

      _initialised = true;

      // ── Camera: fit to lawn bounds ──────────────────────────────────────
      await _fitCamera();
    } catch (e) {
      debugPrint('[MapLayerService] initialise error: $e');
    }
  }

  // ─── Incremental update ───────────────────────────────────────────────────

  /// Hot-swap source data without rebuilding layers.
  /// MapLibre re-tiles the new file internally at the native render thread.
  Future<void> updateSource(String newFileUri) async {
    if (_ctrl == null || !_initialised) return;
    try {
      // 在 Isolate 里解析，不阻塞 UI 线程
      final geoJsonMap = await readGeoJsonFileAsMap(newFileUri);
      await _ctrl!.setGeoJsonSource(kSourceId, geoJsonMap);
    } catch (e) {
      debugPrint('[MapLayerService] updateSource error: $e');
    }
  }


  /**
   * 方案二如下：
   */

  // Future<void> updateSource(String newFileUri) async {
  //   if (_ctrl == null || !_initialised) return;
  //   try {
  //     final path = newFileUri.replaceFirst('file://', '');
  //     final jsonStr = await File(path).readAsString();
  //
  //     // 用 dynamic 绕过类型限制，直接传字符串
  //     // maplibre_gl 底层 Platform Channel 实际接受 String
  //     await (_ctrl!.setGeoJsonSource as dynamic)(kSourceId, jsonStr);
  //   } catch (e) {
  //     debugPrint('[MapLayerService] updateSource error: $e');
  //   }
  // }

  // ─── Camera helpers ───────────────────────────────────────────────────────

  Future<void> _fitCamera() async {
    final c = _ctrl;
    if (c == null) return;
    await c.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: const LatLng(_kDefaultBoundsSwLat, _kDefaultBoundsSwLng),
          northeast: const LatLng(_kDefaultBoundsNeLat, _kDefaultBoundsNeLng),
        ),
        left: 40, top: 80, right: 40, bottom: 80,
      ),
      duration: const Duration(milliseconds: 900),
    );
  }

  Future<void> zoomIn()  => _ctrl?.animateCamera(
        CameraUpdate.zoomIn(), duration: const Duration(milliseconds: 220)) ?? Future.value();

  Future<void> zoomOut() => _ctrl?.animateCamera(
        CameraUpdate.zoomOut(), duration: const Duration(milliseconds: 220)) ?? Future.value();

  Future<void> fitAll()  => _fitCamera();
}
