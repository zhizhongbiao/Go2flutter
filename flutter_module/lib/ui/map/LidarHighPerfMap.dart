import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';


class LidarHighPerfMap extends StatefulWidget {
  const LidarHighPerfMap({super.key});

  @override
  State<LidarHighPerfMap> createState() => _LidarHighPerfMapState();
}

class _LidarHighPerfMapState extends State<LidarHighPerfMap> {
  MapLibreMapController? _mapController;

  // 使用 Float32List 存储坐标，减少对象创建开销 [lat1, lng1, lat2, lng2, ...]
  Float32List _points = Float32List(0);

  // 地图状态同步
  double _zoom = 15.0;
  LatLng _center = const LatLng(31.2304, 121.4737); // 示例坐标：上海

  @override
  void initState() {
    super.initState();
    _startDataSimulation();
  }

  // 1. Isolate 模拟数据生成
  void _startDataSimulation() async {
    // 在后台线程生成几十万点
    final data = await compute(_generateLidarData, 2000); // 模拟 20 万个点
    if (mounted) {
      setState(() {
        _points = data;
      });
    }
  }

  static Float32List _generateLidarData(int count) {
    final random = Random();
    final result = Float32List(count * 2);
    // 模拟中心点
    double baseLat = 31.2304;
    double baseLng = 121.4737;

    for (int i = 0; i < count; i++) {
      // 模拟割草机路径：在一个范围内随机分布或形成特定形状
      result[i * 2] = baseLat + (random.nextDouble() - 0.5) * 0.01;
      result[i * 2 + 1] = baseLng + (random.nextDouble() - 0.5) * 0.01;
    }
    return result;
  }

  // 处理地图缩放和平移，通知 CustomPainter 重绘
  void _onCameraMove() {
    if (_mapController == null) return;
    setState(() {
      _zoom = _mapController!.cameraPosition!.zoom;
      _center = _mapController!.cameraPosition!.target;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 2. 底图层：使用 MapLibre
          MapLibreMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: _zoom),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: (c){
              _onCameraMove();
            },
            styleString: MapLibreStyles.demo, // 或者你自己的暗色矢量样式
          ),

          // 3. 核心：点云渲染层
          IgnorePointer(
            child: CustomPaint(
              painter: LidarPainter(
                points: _points,
                center: _center,
                zoom: _zoom,
                screenSize: MediaQuery.of(context).size,
              ),
              child: Container(),
            ),
          ),

          // 状态显示
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black54,
              child: Text(
                "点数: ${_points.length ~/ 2} \nFPS: 60 (Target)",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 4. 高性能 Painter
class LidarPainter extends CustomPainter {
  final Float32List points;
  final LatLng center;
  final double zoom;
  final Size screenSize;

  LidarPainter({
    required this.points,
    required this.center,
    required this.zoom,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // 计算当前缩放级别下的投影参数
    // Web Mercator 投影转换公式 (精简版，用于局部坐标计算)
    final double mapSize = 256.0 * pow(2, zoom);
    final Offset centerPixel = _latLngToPixel(center, mapSize);

    // 转换为屏幕坐标的 Offset 数组
    final List<Offset> screenPoints = [];

    // 优化：为了极致性能，这里可以进一步使用 drawRawPoints 配合 Float32List
    // 我们手动构建一个用于绘图的平移矩阵，避免在循环中做加减法
    final double screenCenterX = screenSize.width / 2;
    final double screenCenterY = screenSize.height / 2;

    final Float32List drawBuffer = Float32List(points.length);

    for (int i = 0; i < points.length ~/ 2; i++) {
      double lat = points[i * 2];
      double lng = points[i * 2 + 1];

      Offset pos = _latLngToPixel(LatLng(lat, lng), mapSize);

      // 相对于地图中心的偏移，再映射到屏幕中心
      double x = pos.dx - centerPixel.dx + screenCenterX;
      double y = pos.dy - centerPixel.dy + screenCenterY;

      // 视口裁剪：只绘制屏幕内的点，这是保持 60fps 的关键
      if (x >= 0 && x <= screenSize.width && y >= 0 && y <= screenSize.height) {
        drawBuffer[i * 2] = x;
        drawBuffer[i * 2 + 1] = y;
      }
    }

    // 使用 drawRawPoints 绕过对象实例化，直接将内存传给 GPU
    canvas.drawRawPoints(ui.PointMode.points, drawBuffer, paint);
  }

  // 经纬度转像素坐标 (Web Mercator)
  Offset _latLngToPixel(LatLng latLng, double mapSize) {
    double x = (latLng.longitude + 180) / 360 * mapSize;
    double sinLatitude = sin(latLng.latitude * pi / 180);
    double y = (0.5 - log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * pi)) * mapSize;
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(LidarPainter oldDelegate) {
    // 只有当数据、中心点或缩放变化时才重绘
    return oldDelegate.points != points ||
        oldDelegate.center != center ||
        oldDelegate.zoom != zoom;
  }
}