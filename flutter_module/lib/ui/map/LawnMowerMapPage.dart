import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'constants.dart';   // 假设你的 styleUrl 在这里定义

class LawnMowerMapPage extends StatefulWidget {
  const LawnMowerMapPage({super.key});

  @override
  State<LawnMowerMapPage> createState() => _LawnMowerMapPageState();
}

class _LawnMowerMapPageState extends State<LawnMowerMapPage> {
  MapLibreMapController? controller;

  // 当前草坪边界
  List<LatLng> boundaryPoints = [];

  @override
  void initState() {
    super.initState();

    // 示例边界（一个比较大的矩形区域，便于看到）
    boundaryPoints = [
      LatLng(22.920, 113.215),
      LatLng(22.940, 113.215),
      LatLng(22.940, 113.245),
      LatLng(22.920, 113.245),
      LatLng(22.920, 113.215), // 必须闭合
    ];
  }

  void _onMapCreated(MapLibreMapController mapController) async {
    controller = mapController;
    await _addBoundaryLayer();
  }

  Future<void> _addBoundaryLayer() async {
    if (controller == null) return;

    // 1. 添加 Source
    await controller!.addGeoJsonSource("boundary_source", {
      "type": "Feature",
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          boundaryPoints.map((p) => [p.longitude, p.latitude]).toList()
        ]
      }
    });

    // 2. 添加半透明填充（便于看到区域）
    await controller!.addFillLayer(
      "boundary_source",
      "boundary_fill",
      FillLayerProperties(
        fillColor: "#4CAF50",
        fillOpacity: 0.3,
      ),
    );

    // 3. 添加边界线（强烈颜色 + 粗线）
    await controller!.addLineLayer(
      "boundary_source",
      "boundary_line",
      LineLayerProperties(
        lineColor: "#FF0000",     // 醒目红色
        lineWidth: 5.0,           // 加粗
        lineOpacity: 1.0,
        lineJoin: "round",
        lineCap: "round",
      ),
    );

    print("✅ 边界线 Layer 添加完成");
  }

  /// 更新边界（后续割草机返回数据时调用）
  Future<void> updateBoundary(List<LatLng> newBoundary) async {
    boundaryPoints = newBoundary;
    await controller?.setGeoJsonSource("boundary_source", {
      "type": "Feature",
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          newBoundary.map((p) => [p.longitude, p.latitude]).toList()
        ]
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('割草机地图 - 矢量边界'),
        backgroundColor: Colors.black87,
      ),
      body: MapLibreMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(22.93, 113.23),
          zoom: 18.0,
        ),
        styleString: styleUrl,           // 使用你项目中统一的 styleUrl
        onMapCreated: _onMapCreated,
        trackCameraPosition: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 测试更新边界
          final newBoundary = List<LatLng>.from(boundaryPoints);
          newBoundary[2] = LatLng(22.945, 113.250); // 修改一个点
          updateBoundary(newBoundary);
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }
}