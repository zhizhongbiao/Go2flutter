import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:maplibre_gl/maplibre_gl.dart';
import 'dart:ui' as ui;
import 'MapState.dart';

class LidarMowerMap extends StatefulWidget {
  const LidarMowerMap({super.key});

  @override
  State<LidarMowerMap> createState() => _LidarMowerMapState();
}

class _LidarMowerMapState extends State<LidarMowerMap> {
  MapLibreMapController? _mapController;

  // Isolate 传过来的归一化坐标和颜色
  Float32List _points = Float32List(0);
  Int32List _colors = Int32List(0);

  // 初始视角设定在上海，默认缩放为 18（局部街道视角）
  final ValueNotifier<MapState> _mapNotifier = ValueNotifier(
    MapState(const LatLng(31.2304, 121.4737), 18.0),
  );

  @override
  void initState() {
    super.initState();
    _startLidarStream();
  }

  // 1. 开启独立线程计算
  void _startLidarStream() async {
    final rp = ReceivePort();
    await Isolate.spawn(_generateColorLidarData, rp.sendPort);

    rp.listen((msg) {
      if (msg is List && msg.length == 2) {
        final pData = msg[0] as TransferableTypedData;
        final cData = msg[1] as TransferableTypedData;

        if (mounted) {
          setState(() {
            _points = pData.materialize().asFloat32List();
            _colors = cData.materialize().asInt32List();
          });
        }
      }
    });
  }

  // 2. Isolate 后台点云数据模拟（核心修改：缩小范围，模拟地形）
  static void _generateColorLidarData(SendPort sp) {
    const int count = 100000; // 100 万点
    final points = Float32List(count * 2);
    final colors = Int32List(count);
    final random = Random();

    // 每 150ms 刷新一帧数据
    Timer.periodic(const Duration(milliseconds: 150), (t) {
      for (int i = 0; i < count; i++) {
        // 【修正】范围缩小至 0.0005（约 50 米），模拟真实的割草机局部地图
        double lat = 31.2304 + (random.nextDouble() - 0.5) * 0.0005;
        double lng = 121.4737 + (random.nextDouble() - 0.5) * 0.0005;

        // 【修正】引入波浪形函数模拟地形的高低起伏 (0.0 到 1.0 之间)
        double z = (sin(lat * 50000) * cos(lng * 50000) + 1) / 2;

        // 预计算 Web Mercator 归一化坐标
        points[i * 2] = (lng + 180) / 360;
        double sinLat = sin(lat * pi / 180);
        points[i * 2 + 1] = (0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi));

        // 高度映射到颜色：Z越小越蓝(低处)，Z越大越红(高处)
        int r = (z * 255).toInt();
        int g = ((1 - z) * 150).toInt(); // 增加一点绿色过渡
        int b = ((1 - z) * 255).toInt();

        // 0xAARRGGBB 格式
        colors[i] = (0xFF << 24) | (r << 16) | (g << 8) | b;
      }

      // 零拷贝发送
      sp.send([
        TransferableTypedData.fromList([points]),
        TransferableTypedData.fromList([colors])
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 底图层：静态隔离
          RepaintBoundary(
            child: MapLibreMap(
              initialCameraPosition: CameraPosition(
                  target: _mapNotifier.value.center,
                  zoom: _mapNotifier.value.zoom
              ),
              onMapCreated: (c) => _mapController = c,
              styleString: MapLibreStyles.demo,
              onCameraMove: (c) {
                if (_mapController == null) return;
                _mapNotifier.value = MapState(
                  _mapController!.cameraPosition!.target,
                  _mapController!.cameraPosition!.zoom,
                );
              },
            ),
          ),

          // 点云渲染层：动态刷新
          IgnorePointer(
            child: ValueListenableBuilder<MapState>(
              valueListenable: _mapNotifier,
              builder: (context, map, _) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: LidarMowerPainter(
                    points: _points,
                    colors: _colors,
                    center: map.center,
                    zoom: map.zoom,
                  ),
                );
              },
            ),
          ),

          // 图例面板
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Positioned(
      bottom: 40, right: 20,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24)
        ),
        child: Column(
          children: [
            const Text("Height", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Container(
              height: 100, width: 15,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.red, Colors.purple, Colors.blue],
                ),
              ),
            ),
            const SizedBox(height: 5),
            const Text("Low", style: TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// 3. 高性能渲染器（三角形化散点方案）
class LidarMowerPainter extends CustomPainter {
  final Float32List points;
  final Int32List colors;
  final LatLng center;
  final double zoom;

  LidarMowerPainter({
    required this.points,
    required this.colors,
    required this.center,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || colors.isEmpty) return;

    final double mapSize = 256.0 * pow(2, zoom);
    final double centerNX = (center.longitude + 180) / 360;
    final double sinLat = sin(center.latitude * pi / 180);
    final double centerNY = (0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi));

    final double sCX = size.width / 2;
    final double sCY = size.height / 2;

    // 【核心黑科技】: 1个点变1个三角形 (3个顶点)。因此空间要乘以 3
    final Float32List trianglePoints = Float32List(points.length ~/ 2 * 6);
    final Int32List triangleColors = Int32List(points.length ~/ 2 * 3);

    // 【修正】可以控制点云的粗细大小
    // Zoom 越大（越近），点应该显得越大。这里做一个简单的自适应
    final double pointSize = zoom > 16 ? 2.5 : 1.5;

    int triCount = 0;
    for (int i = 0; i < points.length ~/ 2; i++) {
      double sx = sCX + (points[i * 2] - centerNX) * mapSize;
      double sy = sCY + (points[i * 2 + 1] - centerNY) * mapSize;

      // 视口裁剪：只画屏幕里的点
      if (sx >= -pointSize && sx <= size.width && sy >= -pointSize && sy <= size.height) {
        int vIdx = triCount * 6; // 每个三角形占 6 个 Float (3个点 * 2个坐标)
        int cIdx = triCount * 3; // 每个三角形占 3 个 Color (3个点 * 1个颜色)
        int color = colors[i];

        // 构建一个微小的等腰三角形代表一个“点”
        // 顶点 1 (顶部)
        trianglePoints[vIdx] = sx;
        trianglePoints[vIdx + 1] = sy;
        // 顶点 2 (右下)
        trianglePoints[vIdx + 2] = sx + pointSize;
        trianglePoints[vIdx + 3] = sy + pointSize;
        // 顶点 3 (左下)
        trianglePoints[vIdx + 4] = sx - pointSize;
        trianglePoints[vIdx + 5] = sy + pointSize;

        // 三个顶点涂上同一个颜色
        triangleColors[cIdx] = color;
        triangleColors[cIdx + 1] = color;
        triangleColors[cIdx + 2] = color;

        triCount++;
      }
    }

    if (triCount == 0) return;

    // 使用 VertexMode.triangles，完美兼容所有 Flutter 版本
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      trianglePoints.sublist(0, triCount * 6),
      colors: triangleColors.sublist(0, triCount * 3),
    );

    // BlendMode.dst 会直接使用我们传入的颜色缓冲
    canvas.drawVertices(vertices, BlendMode.dst, Paint());
  }

  @override
  bool shouldRepaint(LidarMowerPainter old) => true;
}