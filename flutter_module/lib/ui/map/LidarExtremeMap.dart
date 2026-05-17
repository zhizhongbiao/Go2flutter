import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';


import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'MapCameraState.dart';

import 'dart:ui' as ui;

class LidarExtremeMap extends StatefulWidget {
  const LidarExtremeMap({super.key});

  @override
  State<LidarExtremeMap> createState() => _LidarExtremeMapState();
}

class _LidarExtremeMapState extends State<LidarExtremeMap> {
  MapLibreMapController? _mapController;

  // 核心数据：百万点云的 Web Mercator 归一化坐标
  Float32List _normalizedPoints = Float32List(0);

  // 极致优化：使用 ValueNotifier 隔离刷新区域
  final ValueNotifier<MapCameraState> _cameraNotifier = ValueNotifier(
    MapCameraState(const LatLng(31.2304, 121.4737), 15.0),
  );

  @override
  void initState() {
    super.initState();
    _spawnLidarDataIsolate();
  }

  // 1. Isolate 并发计算层
  Future<void> _spawnLidarDataIsolate() async {
    final receivePort = ReceivePort();
    await Isolate.spawn(_lidarDataWorker, receivePort.sendPort);

    receivePort.listen((message) {
      if (message is TransferableTypedData) {
        // 零拷贝获取数据
        final buffer = message.materialize().asFloat32List();
        if (mounted) {
          // 这里可以使用 setState，因为数据更新频率通常低于 60fps（比如 10Hz）
          setState(() => _normalizedPoints = buffer );
        }
      }
    });
  }

  static void _lidarDataWorker(SendPort sendPort) {
    const int pointCount = 1000000;
    final Float32List buffer = Float32List(pointCount * 2);
    final random = Random();

    // 模拟数据循环生成
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      for (int i = 0; i < pointCount; i++) {
        // 模拟轨迹：在上海中心城区附近随机分布
        double lat = 31.2304 + (random.nextDouble() - 0.5) * 0.05;
        double lng = 121.4737 + (random.nextDouble() - 0.5) * 0.05;

        // 核心：在后台完成 Web Mercator 归一化投影预计算
        double x = (lng + 180) / 360;
        double sinLat = sin(lat * pi / 180);
        double y = (0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi));

        buffer[i * 2] = x;
        buffer[i * 2 + 1] = y;
      }
      final transferable = TransferableTypedData.fromList([buffer]);
      sendPort.send(transferable);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 2. 底图层：永不被外部 setState 刷新的静态层
          RepaintBoundary(
            child: MapLibreMap(
              initialCameraPosition: CameraPosition(
                target: _cameraNotifier.value.center,
                zoom: _cameraNotifier.value.zoom,
              ),
              styleString: MapLibreStyles.demo,
              onMapCreated: (c) => _mapController = c,
              onCameraMove: (c) {
                if (_mapController == null) return;
                // 仅更新状态，不触发 Widget rebuild
                _cameraNotifier.value = MapCameraState(
                  _mapController!.cameraPosition!.target,
                  _mapController!.cameraPosition!.zoom,
                );
              },
            ),
          ),

          // 3. 动态渲染层：使用 ValueListenableBuilder 局部刷新
          IgnorePointer(
            child: RepaintBoundary(
              child: ValueListenableBuilder<MapCameraState>(
                valueListenable: _cameraNotifier,
                builder: (context, camera, _) {
                  return CustomPaint(
                    size: Size.infinite,
                    painter: LidarExtremePainter(
                      normalizedPoints: _normalizedPoints,
                      mapCenter: camera.center,
                      mapZoom: camera.zoom,
                    ),
                  );
                },
              ),
            ),
          ),

          _buildOverlayUI(),
        ],
      ),
    );
  }

  Widget _buildOverlayUI() {
    return Positioned(
      top: 50, left: 20,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Lidar High Performance Mode", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            Divider(color: Colors.white24),
            Text("Data Points: 1,000,000", style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text("Render: GPU DrawRawPoints", style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text("Transport: Zero-Copy Isolate", style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class LidarExtremePainter extends CustomPainter {
  final Float32List normalizedPoints;
  final LatLng mapCenter;
  final double mapZoom;

  LidarExtremePainter({
    required this.normalizedPoints,
    required this.mapCenter,
    required this.mapZoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (normalizedPoints.isEmpty) return;

    final paint = Paint()
      ..color = const Color(0xFF00FF88).withOpacity(0.7)
      ..strokeWidth = 1.0
      ..isAntiAlias = false;

    // 计算当前缩放下的总像素大小
    final double mapSize = 256.0 * pow(2, mapZoom);

    // 中心点归一化坐标
    final double centerNX = (mapCenter.longitude + 180) / 360;
    final double sinLat = sin(mapCenter.latitude * pi / 180);
    final double centerNY = (0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi));

    final double screenCX = size.width / 2;
    final double screenCY = size.height / 2;

    // 预分配缓冲区，避免循环内创建对象
    final Float32List screenCoords = Float32List(normalizedPoints.length);
    int count = 0;

    for (int i = 0; i < normalizedPoints.length ~/ 2; i++) {
      final double nx = normalizedPoints[i * 2];
      final double ny = normalizedPoints[i * 2 + 1];

      // 极致性能：直接通过差值乘法计算屏幕位置
      final double sx = screenCX + (nx - centerNX) * mapSize;
      final double sy = screenCY + (ny - centerNY) * mapSize;

      // 简单的视口裁剪
      if (sx >= 0 && sx <= size.width && sy >= 0 && sy <= size.height) {
        screenCoords[count * 2] = sx;
        screenCoords[count * 2 + 1] = sy;
        count++;
      }
    }

    // 将过滤后的 Float32List 直接推给底层
    if (count > 0) {
      canvas.drawRawPoints(
          ui.PointMode.points,
          screenCoords.sublist(0, count * 2),
          paint
      );
    }
  }

  @override
  bool shouldRepaint(LidarExtremePainter oldDelegate) => true;
}