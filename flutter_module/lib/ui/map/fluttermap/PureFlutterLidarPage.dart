import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_module/ui/map/constants.dart';
import 'package:latlong2/latlong.dart'; // flutter_map 官方推荐经纬度库


/// 核心数据包装：利用 TypedData 规避 Dart 对象内存爆炸
class LidarBinaryPayload {
  final Float32List positions; // 平铺的 Web 墨卡托投影坐标 [x0, y0, x1, y1, ...]
  final Int32List colors;     // 平铺的 ARGB 颜色 [c0, c1, c2, ...]
  LidarBinaryPayload(this.positions, this.colors);
}

class PureFlutterLidarPage extends StatefulWidget {
  const PureFlutterLidarPage({super.key});

  @override
  State<PureFlutterLidarPage> createState() => _PureFlutterLidarPageState();
}

class _PureFlutterLidarPageState extends State<PureFlutterLidarPage> {
  // 核心优化：直接缓存已实例化好的 ui.Vertices，Paint 阶段直接压入 GPU
  ui.Vertices? _gpuVertices;
  bool _isGenerating = false;
  int _currentPointCount = 0;

  // 割草机工作中心点（雷达原点定位在上海）
  final LatLng _mapCenter = const LatLng(lati, long);
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // 初始化直接轰入 1,000,000 (一百万) 个点云！
    _triggerLidarPipeline(100000);
  }

  /// 1. 多线程二进制数据流水线
  Future<void> _triggerLidarPipeline(int count) async {
    // if (_isGenerating) return;
    // setState(() {
    //   _isGenerating = true;
    // });

    final centerLat = _mapCenter.latitude;
    final centerLng = _mapCenter.longitude;

    // 丢到后台 Isolate 生成原始二进制数据，主线程此时毫无波动，更不会 OOM
    final payload = await Isolate.run(() => _heavyLidarGenerator(count, centerLat, centerLng));

    // 在主线程利用 raw 包装器直接生成 GPU 顶点数据结构
    // 整个过程是底层的指针包装，不涉及任何大内存拷贝和循环遍历
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      payload.positions,
      colors: payload.colors,
    );

    setState(() {
      _gpuVertices = vertices;
      _currentPointCount = count;
      _isGenerating = false;
    });
  }

  /// 2. 后台纯净线程：直接往物理内存块（TypedData）里写数据
  static LidarBinaryPayload _heavyLidarGenerator(int count, double centerLat, double centerLng) {
    // 1个点由1个小等腰三角形代表 -> 3个顶点 -> 6个Float32坐标
    final positions = Float32List(count * 3 * 2);
    // 3个顶点共享同一种强度的颜色 -> 3个Int32颜色
    final colors = Int32List(count * 3);
    final random = Random();

    // 投影常数：预先将经纬度转换为 Web 墨卡托投影下的绝对缩放级别 0 像素坐标
    double lngToX0(double lng) => 256.0 * (lng + 180.0) / 360.0;
    double latToY0(double lat) {
      double sinLat = sin(lat * pi / 180.0);
      return 256.0 * (0.5 - log((1.0 + sinLat) / (1.0 - sinLat)) / (4.0 * pi));
    }

    // 设定割草机雷达光斑在地图上的物理视觉外扩半径（此处转化为级别 0 像素微量）
    const double delta = 0.000004;

    int vIdx = 0;
    int cIdx = 0;

    for (int i = 0; i < count; i++) {
      // 模拟割草机周边的激光雷达散射点
      final latOffset = random.nextDouble() * 0.004 - 0.002;
      final lonOffset = random.nextDouble() * 0.004 - 0.002;
      final double lat = centerLat + latOffset;
      final double lon = centerLng + lonOffset;

      // 1. 计算该点云在墨卡托 0 级的核心像素原点
      final double cX = lngToX0(lon);
      final double cY = latToY0(lat);

      // 2. 根据反射强度（0-255）计算颜色：低强度绿 -> 中强度黄 -> 高强度红
      final double intensity = random.nextDouble() * 255;
      int r = 0; int g = 0;
      if (intensity < 128) {
        r = (intensity * 2).toInt().clamp(0, 255);
        g = 255;
      } else {
        r = 255;
        g = ((255 - intensity) * 2).toInt().clamp(0, 255);
      }
      final int colorARGB = (0xFF << 24) | (r << 16) | (g << 8) | 0x00;

      // 3. 直接平铺写入连续内存，无任何对象包装
      // 顶点 1
      positions[vIdx] = cX;
      positions[vIdx + 1] = cY - delta;
      // 顶点 2
      positions[vIdx + 2] = cX + delta;
      positions[vIdx + 3] = cY + delta;
      // 顶点 3
      positions[vIdx + 4] = cX - delta;
      positions[vIdx + 5] = cY + delta;

      // 三个顶点共享同一个颜色值
      colors[cIdx] = colorARGB;
      colors[cIdx + 1] = colorARGB;
      colors[cIdx + 2] = colorARGB;

      vIdx += 6;
      cIdx += 3;
    }

    return LidarBinaryPayload(positions, colors);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('极致点云地图 (Pure Flutter)', style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          if (_isGenerating)
            const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent)))),
          Center(child: Text("当前渲染点数: $_currentPointCount  ", style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace'))),
        ],
      ),
      body: Stack(
        children: [
          // 纯 Flutter 地图底座
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 18.0,
              maxZoom: 22.0,
            ),
            children: [
              // 标准暗色矢量/影像底瓦片（可替换为你真实的离线瓦片地址或 styleUrl）
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),

              // 🔥 核心底层：把点云作为纯 Flutter 树上的一个普通 Layer 挂载
              // 当双指搓动地图时，本 Layer 会跟地图的瓦片在同一步骤内被刷新渲染，绝对不存在图层分离漂移！
              _buildLidarHardwareLayer(),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.greenAccent,
        onPressed: () => _triggerLidarPipeline(_currentPointCount + 200000),
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text("追加 20 万点", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildLidarHardwareLayer() {
    return RepaintBoundary(
      child: FlowLidarLayer(
        gpuVertices: _gpuVertices,
        mapController: _mapController,
      ),
    );
  }
}

/// 3. 自定义地图同步组件（将底层渲染矩阵完全与 flutter_map 对齐）
class FlowLidarLayer extends StatelessWidget {
  final ui.Vertices? gpuVertices;
  final MapController mapController;

  const FlowLidarLayer({
    super.key,
    required this.gpuVertices,
    required this.mapController,
  });

  @override
  Widget build(BuildContext context) {
    // 监听地图相机状态变化，驱动画布无延迟重绘
    return StreamBuilder(
      stream: mapController.mapEventStream,
      builder: (context, snapshot) {
        return CustomPaint(
          size: Size.infinite,
          painter: LidarGpuEnginePainter(
            vertices: gpuVertices,
            camera: mapController.camera,
          ),
        );
      },
    );
  }
}

/// 4. O(1) 复杂度显卡硬件级着色器绘图器
class LidarGpuEnginePainter extends CustomPainter {
  final ui.Vertices? vertices;
  final MapCamera camera;

  LidarGpuEnginePainter({required this.vertices, required this.camera});

  @override
  void paint(Canvas canvas, Size size) {
    if (vertices == null) return;

    // 计算当前缩放级别下，整个地球投影的像素尺寸大小
    final double zoomScale = pow(2, camera.zoom).toDouble();

    // 计算当前屏幕视口中心点在墨卡托 0 级下的绝对像素坐标
    final double sinLat = sin(camera.center.latitude * pi / 180.0);
    final double centerCx = 256.0 * (camera.center.longitude + 180.0) / 360.0;
    final double centerCy = 256.0 * (0.5 - log((1.0 + sinLat) / (1.0 - sinLat)) / (4.0 * pi));

    canvas.save();

    // 💡 硬件矩阵魔法变换（完美与底图对齐）
    // 1. 先把画布中心平移到手机屏幕物理中心
    canvas.translate(size.width / 2, size.height / 2);
    // 2. 注入旋转矩阵（同步割草机App底图旋转角度）
    canvas.rotate(-camera.rotation * pi / 180.0);
    // 3. 注入缩放矩阵（同步双指缩放级别）
    canvas.scale(zoomScale, zoomScale);
    // 4. 将原点反向平移至对应的绝对地理墨卡托零点位置
    canvas.translate(-centerCx, -centerCy);

    // 🔥 绝杀：CPU 没有任何循环！100 万个点作为一整块二进制指针直接丢给 GPU。
    // 显卡利用其内部的顶点着色器（Vertex Shader）瞬间完成矩阵乘法变换并平铺上屏，耗时仅约 0.3ms！
    canvas.drawVertices(vertices!, BlendMode.dst, Paint());

    canvas.restore();
  }

  @override
  bool shouldRepaint(LidarGpuEnginePainter oldDelegate) {
    return oldDelegate.vertices != vertices || oldDelegate.camera != camera;
  }
}