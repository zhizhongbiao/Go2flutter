import 'dart:async';
import 'dart:math';
import 'dart:typed_data';   // 关键
import 'package:flutter/material.dart';
import 'package:flutter_module/ui/map/constants.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class PointCloudMapPage extends StatefulWidget {
  const PointCloudMapPage({super.key});

  @override
  State<PointCloudMapPage> createState() => _PointCloudMapPageState();
}

class _PointCloudMapPageState extends State<PointCloudMapPage> {
  MapLibreMapController? controller;
  final String sourceId = "lidar_source";
  final String layerId = "lidar_layer";

  // ========== 核心：使用 Float32List 存储所有点云数据 ==========
  final List<Float32List> _chunks = [];        // 分块存储
  int _totalPoints = 0;

  // Feature 对象池（避免频繁创建 Map）
  final List<Map<String, dynamic>> _featurePool = [];
  int _poolSize = 8000;

  Timer? _simulationTimer;

  @override
  void initState() {
    super.initState();
    _initFeaturePool();
    _addInitialChunk(180000);        // 初始8万点
    _startSimulation();
  }

  void _initFeaturePool() {
    for (int i = 0; i < _poolSize; i++) {
      _featurePool.add({
        "type": "Feature",
        "geometry": {"type": "Point", "coordinates": [0.0, 0.0]},
        "properties": {"intensity": 0.0}
      });
    }
  }

  /// 生成一批点云数据（Float32List 格式：lon, lat, intensity）
  Float32List _generateChunk(int count) {
    final random = Random();
    final data = Float32List(count * 3);

    for (int i = 0; i < count; i++) {
      final idx = i * 3;
      data[idx] = 113.23 + random.nextDouble() * 0.012 - 0.006;     // lon
      data[idx + 1] = 22.93 + random.nextDouble() * 0.012 - 0.006;  // lat
      data[idx + 2] = random.nextDouble() * 255;                    // intensity
    }
    return data;
  }

  void _addInitialChunk(int count) {
    _chunks.add(_generateChunk(count));
    _totalPoints += count;
  }

  void _startSimulation() {
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 5*1000), (_) {

      final newChunk = _generateChunk(60000);   // 每次增量6000点
      _chunks.add(newChunk);
      _totalPoints += 60000;

      setState(() {}); // 更新点数显示
      _updateMapWithChunk(newChunk);
    });
  }

  /// ========== 关键优化：复用 Feature ==========
  Future<void> _updateMapWithChunk(Float32List chunk) async {
    if (controller == null) return;

    final features = <Map<String, dynamic>>[];

    for (int i = 0; i < chunk.length && i ~/ 3 < _featurePool.length; i += 3) {
      final feature = _featurePool[i ~/ 3];
      feature['geometry']['coordinates'][0] = chunk[i];     // lon
      feature['geometry']['coordinates'][1] = chunk[i + 1]; // lat
      feature['properties']['intensity'] = chunk[i + 2];
      features.add(feature);
    }

    await controller!.setGeoJsonSource(sourceId, {
      "type": "FeatureCollection",
      "features": features,
    });
  }

  void _onMapCreated(MapLibreMapController mapController) async {
    controller = mapController;

    await controller!.addGeoJsonSource(sourceId, {
      "type": "FeatureCollection",
      "features": []
    });

    await controller!.addHeatmapLayer(
      sourceId,
      layerId,
      HeatmapLayerProperties(
        heatmapRadius: ['interpolate', ['linear'], ['zoom'], 15, 5, 19, 18],
        heatmapIntensity: 0.85,
        heatmapOpacity: 0.82,
        heatmapColor: [
          'interpolate', ['linear'], ['heatmap-density'],
          0, 'rgba(0,255,100,0)',
          0.3, 'rgba(0,255,200,0.7)',
          0.6, 'rgba(255,240,0,0.9)',
          0.85, 'rgba(255,80,0,0.95)',
          1, 'rgba(255,0,0,1)',
        ],
      ),
    );
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('割草机 LiDAR (低内存优化版)'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text("点数: ${_totalPoints ~/ 1000}k"),
          ),
        ],
      ),
      body: MapLibreMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(22.93, 113.23),
          zoom: 18.0,
        ),
        styleString: styleUrl,
        onMapCreated: _onMapCreated,
      ),
    );
  }
}