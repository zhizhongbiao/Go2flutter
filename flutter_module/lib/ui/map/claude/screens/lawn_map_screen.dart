// lib/screens/lawn_map_screen.dart
//
// Pipeline (all heavy work off UI thread):
//
//   ┌─────────────────────────────────────────────────────────────┐
//   │  Isolate A: generate 300k LiDAR points (CPU-bound)          │
//   │  → FlatPointList (List<double>, zero-copy Isolate transfer)  │
//   └──────────────────────┬──────────────────────────────────────┘
//                          │
//   ┌──────────────────────▼──────────────────────────────────────┐
//   │  Isolate B: serialise GeoJSON → temp file (I/O-bound)        │
//   │  → file:// URI                                               │
//   └──────────────────────┬──────────────────────────────────────┘
//                          │
//   ┌──────────────────────▼──────────────────────────────────────┐
//   │  MapLibre GL (GPU / OpenGL ES render thread)                 │
//   │  addSource(file://) → tile → cluster → circle draw calls     │
//   │  Target: 60 fps, no Dart CPU per frame                       │
//   └─────────────────────────────────────────────────────────────┘

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../constants.dart';
import '../services/lidar_simulator.dart';
import '../services/geojson_writer.dart';
import '../services/map_layer_service.dart';
import '../services/map_style.dart';
import '../models/lidar_point.dart';
import '../widgets/stats_hud.dart';
import '../widgets/legend_panel.dart';
import '../widgets/map_controls.dart';

// LiDAR origin: a garden in Shenzhen 🇨🇳


class LawnMapScreen extends StatefulWidget {
  const LawnMapScreen({super.key});
  @override
  State<LawnMapScreen> createState() => _LawnMapScreenState();
}

class _LawnMapScreenState extends State<LawnMapScreen> {

  // ── Services ───────────────────────────────────────────────────────────────
  final _mapSvc = MapLayerService();
  MapLibreMapController? _mapCtrl;

  // ── UI state ───────────────────────────────────────────────────────────────
  String  _status    = 'Initialising…';
  int     _ptCount   = 0;
  double  _zoom      = 14.5;
  int?    _simMs;
  int?    _writeMs;
  bool    _loading   = false;
  bool    _styleReady = false;
  String? _fileUri;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _runPipeline(); // start immediately; map may not be ready yet → OK
  }

  @override
  void dispose() {
    _mapSvc.detach();
    _mapCtrl?.dispose();
    super.dispose();
  }

  // ── Pipeline ───────────────────────────────────────────────────────────────

  Future<void> _runPipeline() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _status  = 'Simulating ${(kPoints / 1000).toStringAsFixed(0)}K LiDAR points…';
      _fileUri = null;
    });

    // ── Step 1: Generate data in Isolate ────────────────────────────────────
    final t0 = DateTime.now();
    final FlatPointList flat = await runSimulatorInIsolate(
      const SimulatorConfig(
        originLng:    long,
        originLat:    lati,
        targetPoints: kPoints,
      ),
    );
    final simMs = DateTime.now().difference(t0).inMilliseconds;

    if (!mounted) return;
    setState(() {
      _ptCount = flat.pointCount;
      _simMs   = simMs;
      _status  = 'Writing GeoJSON… ($simMs ms sim)';
    });

    // ── Step 2: Serialise → temp file in Isolate ────────────────────────────
    final t1  = DateTime.now();
    final uri = await writeGeoJsonFile(flat);
    final writeMs = DateTime.now().difference(t1).inMilliseconds;

    if (!mounted) return;
    _fileUri = uri;
    setState(() {
      _writeMs = writeMs;
      _status  = 'Rendering GPU tiles…';
    });

    // ── Step 3: Push to MapLibre (only if style is already loaded) ──────────
    if (_styleReady) {
      await _applyToMap(uri);
    }
    // Otherwise _onStyleLoaded() will call _applyToMap.

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _applyToMap(String uri) async {
    await _mapSvc.initialise(uri);
    if (mounted) setState(() => _status = 'Ready  ✓');
  }

  // ── MapLibre callbacks ─────────────────────────────────────────────────────

  void _onMapCreated(MapLibreMapController ctrl) {
    _mapCtrl = ctrl;
    _mapSvc.attach(ctrl);
    ctrl.addListener(_onCameraIdle);
  }

  void _onCameraIdle() {
    final z = _mapCtrl?.cameraPosition?.zoom;
    if (z != null && mounted) setState(() => _zoom = z);
  }

  Future<void> _onStyleLoaded() async {
    _styleReady = true;
    final uri = _fileUri;
    if (uri != null) {
      // Data already ready → apply immediately
      await _applyToMap(uri);
      if (mounted) setState(() => _loading = false);
    }
    // else: pipeline is still running; _runPipeline() will call _applyToMap
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff080f09),
      body: Stack(
        children: [

          // ── MapLibre GL ──────────────────────────────────────────────────
          MapLibreMap(
            styleString: styleUrl,
            initialCameraPosition: const CameraPosition(
              target: latLon,
              zoom: 14.5,
            ),
            onMapCreated:          _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,

            // ── Performance settings ───────────────────────────────────────
            compassEnabled:          false,
            rotateGesturesEnabled:   false,  // no rotation = simpler matrix ops
            tiltGesturesEnabled:     false,  // 2-D only for point cloud
            myLocationEnabled:       false,
            trackCameraPosition:     true,

            // TextureView renders on a dedicated surface → better perf on most
            // Android devices vs SurfaceView (avoids compositing overhead).
            // androidViewType: AndroidViewType.textureView,//可以在原生上做
          ),

          // ── Loading spinner (shown only during pipeline) ─────────────────
          if (_loading) const _LoadingOverlay(),

          // ── HUD widgets ──────────────────────────────────────────────────
          StatsHud(
            pointCount: _ptCount,
            status:     _status,
            zoom:       _zoom,
            simMs:      _simMs,
            writeMs:    _writeMs,
          ),

          const LegendPanel(),

          MapControls(
            loading:   _loading,
            onZoomIn:  _mapSvc.zoomIn,
            onZoomOut: _mapSvc.zoomOut,
            onFitAll:  _mapSvc.fitAll,
            onReload:  _runPipeline,
          ),

          // ── Top bar ───────────────────────────────────────────────────────
          _TopBar(),
        ],
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black45,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34, height: 34,
            child: CircularProgressIndicator(
              color: Color(0xff52d46e), strokeWidth: 2.5,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Building point cloud…',
            style: TextStyle(
              color: Color(0xff9effc4),
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        height: top + 44,
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.65), Colors.transparent],
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grass, color: Color(0xff52d46e), size: 16),
            SizedBox(width: 8),
            Text(
              'LAWN MOWER  ·  LiDAR POINT CLOUD MAP',
              style: TextStyle(
                color: Color(0xff9effc4),
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
